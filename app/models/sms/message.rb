# models an sms message, either incoming or outgoing
# gets created by adapters when messages are incoming
# and gets created by controllers and sent to adapters for sending when messages are outgoing
#
# to          a string holding a phone number in ITU E.123 format (e.g. "+14445556666")
#             can be nil in case of an incoming message
# from        a string holding a single phone number. can be nil in case of an outgoing message.
# body        a string holding the body of the message
# sent_at     the time the message was sent/received
class Sms::Message < ApplicationRecord
  include MissionBased

  belongs_to :mission

  # User may be nil if sent from an unrecognized number or replying to someone not recognized as user.
  belongs_to :user

  before_create :default_sent_at

  # order by id after created_at to make sure they are in creation order
  scope(:latest_first, ->{ order('created_at DESC, id DESC') })
  scope :since, -> (time) { where('created_at > ?', time) }

  # Remove all non-digit chars and add a plus at the front.
  # (unless the number looks like a shortcode, in which case we leave it alone)
  def self.search_qualifiers
    # We pass explicit SQL here or else we end up with an INNER JOIN which excludes any message
    # with no associated user.
    user_assoc = 'LEFT JOIN users ON users.id = sms_messages.user_id'

    [
      Search::Qualifier.new(name: "content", col: "sms_messages.body", type: :text, default: true),
      Search::Qualifier.new(name: "type", col: "sms_messages.type", type: :text),
      Search::Qualifier.new(name: "date", type: :date,
                            col: "CAST((sms_messages.created_at AT TIME ZONE 'UTC')
                              AT TIME ZONE '#{Time.zone.tzinfo.name}' AS DATE)"),
      Search::Qualifier.new(name: "datetime", col: "sms_messages.created_at", type: :date),
      Search::Qualifier.new(name: "username", col: "users.login", type: :text, assoc: user_assoc, default: true),
      Search::Qualifier.new(name: "name", col: "users.name", type: :text, assoc: user_assoc, default: true),
      Search::Qualifier.new(name: "number", col: ["sms_messages.to", "sms_messages.from"], type: :text, default: true)
    ]
  end

  # searches for sms messages
  # based on User.do_search
  # scope is not used in Message search
  def self.do_search(relation, query, _scope, _options = {})
    # create a search object and generate qualifiers
    search = Search::Search.new(str: query, qualifiers: search_qualifiers)

    # apply the needed associations
    relation = relation.joins(search.associations)

    # apply the conditions
    relation = relation.where(search.sql)
  end

  def received_at
    type == "Sms::Incoming" ? created_at : nil
  end

  def from_shortcode?
    PhoneNormalizer.is_shortcode?(from)
  end

  def sender
    raise NotImplementedError
  end

  def recipient_count
    raise NotImplementedError
  end

  def recipient_numbers
    raise NotImplementedError
  end

  def recipient_hashes(options = {})
    raise NotImplementedError
  end

  def to=(number)
    self[:to] = PhoneNormalizer.normalize(number)
  end

  def from=(number)
    self[:from] = PhoneNormalizer.normalize(number)
  end

  private

  # sets sent_at to now unless it's already set
  def default_sent_at
    self.sent_at = Time.current unless sent_at
  end
end
