# frozen_string_literal: true

module Odk
  # Decorates Questionings for ODK views.
  class QingDecorator < FormItemDecorator
    delegate_all

    def bind_tag(form, subq, xpath_prefix: "/data")
      tag(:bind, nodeset: [xpath_prefix, subq.try(:odk_code)].compact.join("/"),
                 type: binding_type_attrib(subq),
                 required: required? && visible? && subq.first_rank? ? required_value(form) : nil,
                 readonly: default_answer? && read_only? ? "true()" : nil,
                 relevant: relevance,
                 constraint: odk_constraint,
                 "jr:constraintMsg": min_max_error_msg,
                 calculate: calculate,
                 "jr:preload": jr_preload,
                 "jr:preloadParams": jr_preload_params)
    end

    def body_tags(group: nil, render_mode: nil, xpath_prefix:)
      return unless visible?
      render_mode ||= :normal

      # Note that subqings here refers to multiple levels of a cascading select question, not groups.
      # If group is a multilevel_fragment, we are supposed to just render one of the subqings here.
      # This is so they can be wrapped with the appropriate group headers/hint and such.
      subqing_subset = group&.multilevel_fragment? ? [subqings[group.level - 1]] : subqings

      subqing_subset.map do |sq|
        sq.input_tag(render_mode: render_mode, xpath_prefix: xpath_prefix)
      end.reduce(:<<)
    end

    def subqings
      decorate_collection(object.subqings, context: context)
    end

    def decorated_option_set
      @decorated_option_set ||= decorate(option_set)
    end

    def select_one_with_external_csv?
      qtype_name == "select_one" && decorated_option_set.external_csv?
    end

    private

    def default_answer?
      default.present? && qtype.defaultable?
    end

    def calculate
      default_answer? ? Odk::ResponsePatternParser.new(default, src_item: self).to_odk : nil
    end

    def jr_preload
      case metadata_type
      when "formstart", "formend" then "timestamp"
      end
    end

    def jr_preload_params
      case metadata_type
      when "formstart" then "start"
      when "formend" then "end"
      end
    end

    # If a question is required, then determine the appropriate value
    # based on whether the form allows incomplete responses.
    def required_value(form)
      # If form allows incompletes, question is required only if
      # the answer to 'are there missing answers' is 'no'.
      form.allow_incomplete? ? "selected(/data/#{FormDecorator::IR_QUESTION}, 'no')" : "true()"
    end

    def binding_type_attrib(subq)
      # When using external CSV method, ODK wants non-first-level selects to have type 'string'.
      select_one_with_external_csv? && !subq.first_rank? ? "string" : odk_name
    end
  end
end
