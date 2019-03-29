# frozen_string_literal: true

# Generates human readable representation of Skip Rules
class SkipRuleDecorator < ApplicationDecorator
  delegate_all

  def human_readable
    if skip_if == "always"
      I18n.t("skip_rule.instructions.without_conditions", destination: display_dest)
    else
      I18n.t("skip_rule.instructions.with_conditions", destination: display_dest,
                                                       conditions: human_readable_conditions)
    end
  end

  def read_only_header
    destination_directions = I18n.t("skip_rule.skip_to_item", label: display_dest)
    skip_if_directions = I18n.t("skip_rule.skip_if_options.#{skip_if}")
    destination_directions << " " << skip_if_directions
  end

  private

  def human_readable_conditions
    decorated_conditions = ConditionDecorator.decorate_collection(condition_group.members)
    concatenator = condition_group.true_if == "all_met" ? I18n.t("common.AND") : I18n.t("common.OR")
    decorated_conditions.map { |c| c.human_readable(include_code: true) }.join(" #{concatenator} ")
  end

  def display_dest
    if destination == "item"
      prefix = I18n.t("activerecord.models.question.one")
      prefix << " " << "##{dest_item.full_dotted_rank} #{dest_item.code}"
    else
      I18n.t("skip_rule.end_of_form")
    end
  end
end
