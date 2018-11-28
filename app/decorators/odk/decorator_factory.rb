# Makes decorators for various base model types.
module Odk
  class DecoratorFactory
    include Singleton

    def self.decorate(obj, context: {})
      instance.decorate(obj, context: context)
    end

    def self.decorate_collection(objs, context: {})
      objs.map { |obj| instance.decorate(obj, context: context) }
    end

    def decorate(obj, context: {})
      case obj.class.name
      when "Form"
        Odk::FormDecorator.new(obj, context: context)
      when "QingGroup"
        Odk::QingGroupDecorator.new(obj, context: context)
      when "Question"
        Odk::QuestionDecorator.new(obj, context: context)
      when "Questioning"
        Odk::QingDecorator.new(obj, context: context)
      when "Condition"
        Odk::ConditionDecorator.new(obj, context: context)
      when "Subqing"
        Odk::SubqingDecorator.new(obj, context: context)
      when "Forms::ConditionGroup"
        Odk::ConditionGroupDecorator.new(obj, context: context)
      else
        obj
      end
    end
  end
end
