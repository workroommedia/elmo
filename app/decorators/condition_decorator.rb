class ConditionDecorator < ApplicationDecorator
  delegate_all

  # Generates a human readable representation of condition.
  # prefs[:include_code] - Includes the question code in the string.
  #   May not always be desireable e.g. with printable forms.
  def human_readable(prefs = {})
    if ref_qing_id.blank?
      "" # need to return something here to avoid nil errors
    else
      bits = []
      bits << Question.model_name.human
      bits << "##{ref_qing.full_dotted_rank}"
      bits << ref_qing.code if prefs[:include_code]

      if ref_qing_has_options?
        bits << option_node.level_name if ref_qing.multilevel?
        target = option_node.option_name
      else
        target = value
      end

      bits << I18n.t("condition.operators.human_readable.#{op}")
      bits << (numeric_ref_question? ? target : "\"#{target}\"")
      bits.join(" ")
    end
  end
end
