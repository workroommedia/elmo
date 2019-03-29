# frozen_string_literal: true

# Corresponds with a multilevel questioning. An AnswerSet's parent is an AnswerGroup. Its children are Answers
class AnswerSet < ResponseNode
  alias questioning form_item
  alias answers children

  delegate :option_set, to: :questioning

  def option_node_path
    OptionNodePath.new(
      option_set: questioning.option_set,
      target_node: lowest_non_nil_answer.try(:option_node)
    )
  end

  def invalid?
    answers.any?(&:invalid?)
  end

  private

  # Returns the non-nil answer with the lowest rank. May return nil if the set is blank.
  def lowest_non_nil_answer
    answers.reverse.find(&:present?)
  end
end
