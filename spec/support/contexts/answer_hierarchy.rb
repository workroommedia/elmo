# frozen_string_literal: true

# Provides spec helper methods for dealing with hierarchy of response nodes
shared_context "answer hierarchy" do
  def expect_children(node, types, qing_ids, values = nil)
    children = node.children.sort_by(&:new_rank)
    expect(children.map(&:type)).to eq types
    expect(children.map(&:questioning_id)).to eq qing_ids
    expect(children.map(&:new_rank)).to eq((1..children.size).to_a)

    # This expectation can be removed when we remove the old inst_num and rank columns.
    expect(children.map(&:inst_num)).to eq([node.rank] * children.size) if node.parent.is_a?(AnswerGroupSet)

    return if values.nil?

    child_values = children.map { |child| child.is_a?(Answer) ? child.casted_value : nil }
    expect(child_values).to eq values
  end
end
