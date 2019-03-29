class ConditionViewSerializer < ActiveModel::Serializer
  attributes :id, :ref_qing_id, :op, :value, :option_node_id, :option_set_id,
    :form_id, :conditionable_id, :conditionable_type, :operator_options
  format_keys :lower_camel

  has_many :refable_qings, serializer: TargetFormItemSerializer

  def id
    object.id
  end

  def conditionable_id
    object.conditionable_id
  end

  def operator_options
    object.applicable_operator_names.map { |n| {name: I18n.t("condition.operators.select.#{n}"), id: n} }
  end

  def value
    object.value
  end

  def option_set_id
    object.ref_qing.try(:option_set_id)
  end
end
