# frozen_string_literal: true

module Sms
  # Class for building answer hierarchy to mirror question hierarchy
  class AnswerHierarchy
    attr_reader :answer_groups

    def initialize
      # mapping from qing group ID -> answer group
      @answer_groups = {}
    end

    def lookup(qing_group)
      answer_groups[qing_group.id]
    end

    def answer_group_for(qing)
      qing_group = qing.parent
      answer_group = lookup(qing_group) || build_answer_group(qing_group)

      if qing.multilevel?
        answer_set = AnswerSet.new(form_item: qing)
        answer_group.children << answer_set
        answer_set.new_rank = answer_group.children.length
        answer_group = answer_set
      end

      answer_group
    end

    def add_answer(answer_group, answer)
      answer_group.children << answer
      answer.new_rank = answer_group.children.length
      answer
    end

    def save(response)
      root_node = lookup(response.form.root_group)
      root_node.associate_response(response)

      response.root_node = root_node

      # TODO: We can remove the `validate: false` once various validations are
      # removed from the response model
      response.save!(validate: false)
    end

    private

    def build_answer_group(qing_group)
      group = AnswerGroup.new(form_item: qing_group)
      if qing_group.repeatable?
        set = AnswerGroupSet.new(form_item: qing_group)
        set.children << group
        group.new_rank = 1
        add_to_parent(set)
      else
        add_to_parent(group)
      end
      answer_groups[qing_group.id] = group
      group
    end

    # Link the given answer group or set to its parent.
    # This method will create all necessary ancestor groups that do not already exist.
    def add_to_parent(node)
      qing_group = node.form_item
      if qing_group.parent.nil?
        node.new_rank = 1
      else
        parent = lookup(qing_group.parent) || build_answer_group(qing_group.parent)
        parent.children << node
        node.new_rank = parent.children.length
      end
    end
  end
end
