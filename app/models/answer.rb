# frozen_string_literal: true

# An Answer is a single piece of data in response to a single question or sub-question.
# It is always a leaf in a response tree.

class Answer < ResponseNode
  include ActionView::Helpers::NumberHelper
  include PgSearch

  LOCATION_ATTRIBS = %i(latitude longitude altitude accuracy)

  # Convert value to tsvector for use in full text search.
  trigger.before(:insert, :update) do
    "new.tsv := TO_TSVECTOR('simple', COALESCE(
      new.value,
      (SELECT STRING_AGG(opt_name_translation.value, ' ')
        FROM options, jsonb_each_text(options.name_translations) opt_name_translation
        WHERE options.id = new.option_id
          OR options.id IN (SELECT option_id FROM choices WHERE answer_id = new.id)),
      ''
    ));"
  end

  attr_accessor :location_values_replicated
  alias questioning form_item

  belongs_to :option, inverse_of: :answers
  belongs_to :response, inverse_of: :answers, touch: true
  has_many :choices, -> { order(:created_at) }, dependent: :destroy, inverse_of: :answer, autosave: true
  has_many :options, through: :choices
  has_one :media_object, dependent: :destroy, inverse_of: :answer, autosave: true, class_name: "Media::Object"

  before_validation :replicate_location_values
  before_save :replicate_location_values # Doing this twice on purpose, see below.
  before_save :chop_decimals
  before_save :format_location_value
  before_save :round_ints
  before_save :blanks_to_nulls
  before_save :remove_unchecked_choices
  after_save :reset_location_flag

  validates :value, numericality: true, if: -> { should_validate?(:numericality) }
  validate :validate_min_max, if: -> { should_validate?(:min_max) }
  validate :validate_required, if: -> { should_validate?(:required) }
  validate :validate_location, if: -> { should_validate?(:location) }
  validate :validate_date, :validate_datetime

  accepts_nested_attributes_for(:choices)

  delegate :question, :qtype, :qtype_name, :required?, :hidden?, :multimedia?,
    :option_set, :options, :first_level_option_nodes, :condition, :parent_group_name, to: :questioning
  delegate :name, to: :question, prefix: true
  delegate :name, to: :level, prefix: true, allow_nil: true
  delegate :name, to: :option, prefix: true, allow_nil: true
  delegate :mission, to: :response

  scope :public_access, lambda {
    joins(form_item: :question)
      .where("questions.access_level = 'inherit'").order("form_items.rank")
  }
  scope :created_after, ->(date) { includes(:response).where("responses.created_at >= ?", date) }
  scope :created_before, ->(date) { includes(:response).where("responses.created_at <= ?", date) }
  scope :newest_first, -> { includes(:response).order("responses.created_at DESC") }
  scope :first_level_only, lambda { # exclude answers from answer sets that are not first level
    joins("INNER JOIN answers parents ON answers.parent_id = parents.id")
      .where("parents.type != 'AnswerSet' OR answers.new_rank = 0")
  }

  pg_search_scope :search_by_value,
    against: :value,
    using: {
      tsearch: {
        tsvector_column: "tsv",
        prefix: true,
        negation: true
      }
    }

  # gets all location answers for the given mission
  # returns only the response ID and the answer value
  def self.location_answers_for_mission(mission, user = nil, _options = {})
    response_conditions = { mission_id: mission.try(:id) }

    # if the user is not a staffer or higher privilege, only show their own responses
    response_conditions[:user_id] = user.id if user.present? && !user.role?(:staffer, mission)

    # return an AR relation
    joins(:response)
      .joins(%{LEFT JOIN "choices" ON "choices"."answer_id" = "answers"."id"})
      .where(responses: response_conditions)
      .where(%{
        ("answers"."latitude" IS NOT NULL AND "answers"."longitude" IS NOT NULL)
        OR ("choices"."latitude" IS NOT NULL AND "choices"."longitude" IS NOT NULL)
      })
      .select(:response_id,
        %{COALESCE("answers"."latitude", "choices"."latitude") AS "latitude",
          COALESCE("answers"."longitude", "choices"."longitude") AS "longitude"})
      .order(%{"answers"."response_id" DESC})
      .paginate(page: 1, per_page: 1000)
  end

  # Tests if there exists at least one answer referencing the option and questionings with the given IDs.
  def self.any_for_option_and_questionings?(option_id, questioning_ids)
    find_by_sql(["
      SELECT COUNT(*) AS count
      FROM answers a
        LEFT OUTER JOIN choices c ON c.answer_id = a.id
      WHERE a.type = 'Answer'
        AND (a.option_id = ? OR c.option_id = ?)
        AND a.questioning_id IN (?)",
      option_id, option_id, questioning_ids]).first.count > 0
  end

  # This is a temporary method for fetching option_node based on the related OptionSet and Option.
  # Eventually Options will be removed and OptionNodes will be stored on Answers directly.
  def option_node
    OptionNode.where(option_id: option_id, option_set_id: option_set.id).first
  end

  def option_node_id
    option_node.try(:id)
  end

  # This is a temporary method for assigning option based on an OptionNode ID.
  # Eventually Options will be removed and OptionNodes will be stored on Answers directly.
  def option_node_id=(id)
    self.option_id = id.present? ? OptionNode.id_to_option_id(id) : nil
  end

  # If this is an answer to a multilevel select_one question, returns the OptionLevel, else returns nil.
  def level
    option_set.try(:multilevel?) ? option_set.levels[(rank || 1) - 1] : nil
  end

  def choices_by_option
    @choice_hash ||= choices.select(&:checked?).index_by(&:option)
  end

  def all_choices
    # for each option, if we have a matching choice, just return it (checked? defaults to true)
    # otherwise create one and set checked? to false
    options.map { |o| choices_by_option[o] || choices.new(option: o, checked: false) }
  end

  # if this answer is for a location question and the value is not blank, returns a two element array representing the
  # lat long. else returns nil
  def location
    value.split(" ") if location_type_with_value?
  end

  # returns the value for this answer casted to the appropriate data type
  def casted_value
    case qtype.name
    when "date" then date_value
    when "time" then time_value
    when "datetime" then datetime_value
    when "integer", "counter" then value.try(:to_i)
    when "decimal" then value.try(:to_f)
    when "select_one" then option_name
    when "select_multiple" then choices.empty? ? nil : choices.map(&:option_name).sort.join(";")
    else value.blank? ? nil : value
    end
  end

  def lengthy?
    value.present? && value.size >= 1000
  end

  # Checks if answer must be non-empty to be valid.
  # Non-first-rank answers are currently not required even if their questioning is required
  # (i.e. partial answers allowed).
  def required_and_relevant?
    required? && !hidden? && relevant? && first_rank? && qtype.name != "select_multiple"
  end

  # Whether this Answer is the first in its set (i.e. rank is nil or 1)
  def first_rank?
    new_rank.nil? || new_rank.zero?
  end

  # check various fields for blankness
  def empty?
    value.blank? && time_value.blank? && date_value.blank? &&
      datetime_value.blank? && option_id.nil? && media_object.nil?
  end
  alias_method :blank?, :empty?

  # checks if answer is required and relevant but also empty
  def required_but_empty?
    required_and_relevant? && empty?
  end

  def location_type_with_value?
    qtype.name == "location" && value.present?
  end

  def coordinates?
    latitude.present? && longitude.present?
  end

  def from_group?
    questioning && questioning.parent && questioning.parent.type == "QingGroup"
  end

  def option_name
    option.canonical_name if option
  end

  def option_names
    choices.map(&:option).map(&:canonical_name).join(", ") if choices
  end

  def media_object_id
    media_object.try(:id)
  end

  # Attempts to find unassociated media object with given ID and assoicate with this answer.
  # Fails silently if not found.
  def media_object_id=(id)
    if id.nil?
      self.media_object = nil
    elsif media_object_id != id
      self.media_object = Media::Object.find_by(id: id, answer_id: nil)
    end
  end

  def has_media_object?
    !media_object_id.nil?
  end

  def group_level
    questioning.ancestry_depth - 1
  end

  private

  def should_validate?(field)
    # TODO: This line seems to trigger an unnecessary query if response is assigned before it is saved.
    # That is the current theory anyway. A workaround might be to have an ephemeral skip_validation flag
    # when building the object, and call that from the decoder and ODK parser.
    # As it is, the query should be cached, so performance hit shouldn't be too bad.
    return false if response && !response.validate_answers?
    return false if marked_for_destruction?

    case field
    when :numericality
      qtype.numeric? && value.present?
    when :required
      # don't validate requiredness if response says no
      !(response && response.incomplete?)
    when :min_max
      value.present?
    when :location
      qtype.name == "location"
    else
      true
    end
  end

  def parse_token(token)
    BigDecimal(token)
  rescue ArgumentError
    # token was not parsable
    nil
  rescue TypeError
    # token was not a parsable type
    nil
  end

  def replicate_location_values
    # This method is run before_validation and before_save in case validations are skipped.
    # We use this flag to not duplicate effort.
    return if location_values_replicated
    self.location_values_replicated = true

    choices.each(&:replicate_location_values)

    if location_type_with_value?
      tokens = self.value.split(" ")
      LOCATION_ATTRIBS.each_with_index do |a, i|
        self[a] = parse_token(tokens[i])
      end
    elsif option.present? && option.coordinates?
      self.latitude = option.latitude
      self.longitude = option.longitude
    elsif choice = choices.detect(&:coordinates?)
      self.latitude = choice.latitude
      self.longitude = choice.longitude
    end
    true
  end

  # We sometimes save decimals without validating, so we need to be careful
  # not to overflow the DB.
  def chop_decimals
    LOCATION_ATTRIBS.each do |a|
      next if self[a].nil?
      column = self.class.column_for_attribute(a)
      if self[a].abs > 10 ** (column.precision - column.scale)
        self[a] = 0
      end
    end
    self.accuracy = 0 if accuracy.present? && accuracy < 0
    true
  end

  def format_location_value
    if coordinates?
      self.value = sprintf("%.6f %.6f", latitude, longitude)
      if altitude.present?
        self.value << sprintf(" %.3f", altitude)
        if accuracy.present?
          self.value << sprintf(" %.3f", accuracy)
        end
      end
    end
    true
  end

  def round_ints
    self.value = value.to_i if %w(integer counter).include?(qtype.name) && value.present?
    true
  end

  def blanks_to_nulls
    self.value = nil if value.blank?
    true
  end

  def remove_unchecked_choices
    choices.destroy(*choices.reject(&:checked?))
    true
  end

  def validate_required
    errors.add(:value, :required) if required_but_empty?
  end

  def validate_min_max
    val_f = value.to_f
    if question.maximum && (val_f > question.maximum || question.maxstrictly && val_f == question.maximum) ||
      question.minimum && (val_f < question.minimum || question.minstrictly && val_f == question.minimum)
      errors.add(:value, question.min_max_error_msg)
    end
  end

  def validate_location
    # Doesn't make sense to validate lat/lng if copied from options because the user
    # can't do anything about that.
    if location_type_with_value?
      if latitude.nil? || latitude < -90 || latitude > 90
        errors.add(:value, :invalid_latitude)
      end
      if longitude.nil? || longitude < -180 || longitude > 180
        errors.add(:value, :invalid_longitude)
      end
      if altitude.present? && (altitude >= 1e6 || altitude <= -1e6)
        errors.add(:value, :invalid_altitude)
      end
      if accuracy.present?
        if accuracy < 0
          errors.add(:value, :accuracy_negative)
        elsif accuracy >= 1e6
          errors.add(:value, :invalid_accuracy)
        end
      end
    end
  end

  def reset_location_flag
    self.location_values_replicated = false
    true
  end

  def validate_date
    # The date_value before typecast may be a string or a hash (in the case of a multiparam attrib
    # submission like date_value(1i), date_value(2i), etc.) If it is an invalid string, Rails silently
    # coerces it to nil without setting a validation error or raises an error. We want to show a validation
    # error instead.
    return if raw_date_value_ok?("date_value")
    errors.add(:date_value, :invalid_date)
  end

  def validate_datetime
    # See comment for the validate_date method above. The same applies here.
    return if raw_date_value_ok?("datetime_value")
    errors.add(:datetime_value, :invalid_datetime)
  end

  def raw_date_value_ok?(attrib_name)
    raw = read_attribute_before_type_cast(attrib_name)
    return true if raw.blank? || raw.is_a?(Hash)
    begin
      Time.zone.parse(raw.to_s) && true
    rescue ArgumentError
      false
    end
  end
end
