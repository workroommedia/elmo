# Holds behaviors related to standard objects including importing, etc.
# All Replication::Standardizable objects are assumed to be Replication::Replicable also.
module Replication::Standardizable
  extend ActiveSupport::Concern

  included do
    # create self-associations in both directions for is-copy-of relationship
    belongs_to(:original, :class_name => name, :inverse_of => :copies)
    has_many(:copies, :class_name => name, :foreign_key => 'original_id', :inverse_of => :original)

    before_destroy(:unlink_copies)
    before_save(:scrub_original_link_if_becoming_incompatible)
    validate(:non_standard_items_must_have_mission)

    # returns a scope for all standard objects of the current class that are importable to the given mission
    def self.importable_to(mission)
      where(:is_standard => true)
    end

    def self.standardizable_included?
      true
    end
  end

  # Returns the original if this is a standard copy, nil otherwise
  def standard
    standard_copy? ? original : nil
  end

  # returns whether the object is standard or related to a standard object
  def standardized?
    is_standard? || standard_copy?
  end

  # Gets a copy of this object in the given mission, if one. exists.
  # There may be multiple copies, in which case the most recently created one is returned
  def copy_for_mission(mission)
    copies.for_mission(mission).order(created_at: :desc).first
  end

  # adds an obj to the list of copies
  def add_copy(obj)
    # don't add if already there
    copies << obj unless copies.include?(obj)
  end

  def scrub_original_link_if_becoming_incompatible
    if restricted_attribs = replicable_opts[:compatibility]
      restricted_attribs.each do |attrib|
        if send("#{attrib}_changed?")
          self.original_id = nil
          self.standard_copy = false
          break
        end
      end
    end
    return true
  end

  def non_standard_items_must_have_mission
    unless is_standard? || self.mission.present?
      errors.add(:mission, :blank)
    end
  end

  private

  def unlink_copies
    copies.update_all(original_id: nil, standard_copy: false)
  end
end
