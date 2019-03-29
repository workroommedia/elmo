class API::V1::FormSerializer < ActiveModel::Serializer
  attributes :id, :name, :responses_count, :questions

  def filter(keys)
    # Only show questions if show action.
    keys - (scope.params[:action] == "show" ? [] : [:questions])
  end

  def questions
    object.api_visible_questions.as_json(only: [:id, :code], methods: :name)
  end
end
