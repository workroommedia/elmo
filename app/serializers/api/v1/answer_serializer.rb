class API::V1::AnswerSerializer < ActiveModel::Serializer
  attributes :id, :code, :question, :value

  def filter(keys)
    keys -= (scope.params[:controller] == "api/v1/answers" ? [:code, :question] : [])
  end

  def code
    object.question.code
  end

  def question
    object.question.name
  end

  def value
    object.casted_value
  end
end
