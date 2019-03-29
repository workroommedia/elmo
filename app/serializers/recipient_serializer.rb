class RecipientSerializer < ActiveModel::Serializer
  attributes :id, :text

  def text
    object.name
  end
end
