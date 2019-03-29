# frozen_string_literal: true

class Tag < ApplicationRecord
  include MissionBased
  include Comparable
  include Replication::Replicable

  belongs_to :mission
  has_many :taggings, dependent: :destroy
  has_many :questions, through: :taggings

  before_save { |tag| tag.name.downcase! }

  # since reuse_if_match covers all cases where the name is the same, we do not need reuse_in_clone
  replicable reuse_if_match: :name

  MAX_SUGGESTIONS = 5 # The max number of suggestion matches to return
  MAX_NAME_LENGTH = 64

  # Returns an array of Tags matching the given mission and textual query.
  def self.suggestions(mission, query)
    tags = Tag.for_mission(mission)

    # Trim query to maximum length.
    query = query[0...MAX_NAME_LENGTH]

    exact_match = tags.find_by(name: query)
    matches = tags.where("name like ?", "%#{query}%").order(:name).limit(MAX_SUGGESTIONS).to_a

    if exact_match
      # if there was an exact match, put it at the top
      matches.unshift(exact_match).uniq!
    else
      # if there was no exact match, we append a 'new tag' placeholder
      matches << Tag.new(name: query)
    end

    matches
  end

  # Tags that should show at the top of question index page
  def self.mission_tags(mission)
    # In admin mode, return all standard tags
    return where(mission_id: nil).order(:name) if mission.nil?

    # In mission, show all tags for mission
    question_ids = Question.for_mission(mission).pluck(:id)
    mission_id = mission.try(:id) || "null"
    includes(:taggings).where(mission_id: mission_id).order(:name)
  end

  # Sorting
  def <=>(other_tag)
    name <=> other_tag.name
  end

  def as_json(_options = {})
    super(only: %i[id name])
  end
end
