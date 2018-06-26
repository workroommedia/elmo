module Odk
  # Takes a response and odk data. Parses odk data into answer tree for response.
  # Returns the response because in the case of multimedia, the parser may replace
  # the response object the controller passes in with an
  # existing response from the database.
  class ResponseParser
    attr_accessor :response, :raw_odk_xml

    #initialize in a similar way to xml submission
    def initialize(response: nil, files: nil, awaiting_media: false)
      @response = response
      @raw_odk_xml = files.delete(:xml_submission_file).read
      @files = files
      @response.source = "odk"
      @awaiting_media = awaiting_media
    end

    def populate_response
      build_answers(raw_odk_xml)
      response
    end

    private

    # Generates and saves a hash of the complete XML so that multi-chunk media form submissions
    # can be uniquely identified and handled
    def odk_hash
      @odk_hash ||= Digest::SHA256.base64digest @data
    end

    def build_answers(raw_odk_xml)
      data = Nokogiri::XML(raw_odk_xml).root
      lookup_and_check_form(id: data["id"], version: data["version"])
      if existing_response
        # Response mission should already be set - TODO: consider moving to constructor or lookup_and_check_form
        raise "Submissions must have a mission" if response.mission.nil?
        add_media_to_existing_response
      else
        raise "Submissions must have a mission" if response.mission.nil?
        if @awaiting_media
          response.odk_hash = odk_hash
        else
          response.odk_hash = nil
        end
        build_answer_tree(data, response.form)
        response.associate_tree(response.root_node)
      end

      response.save(validate: false)
    end

    def add_media_to_existing_response
      candidate_answers = response.answers.select{|a| a.pending_file_name.present?}
      candidate_answers.each do |a|
        #file = @files[a.pending_file_name]
        #if file.present?
          populate_multimedia_answer(a, a.pending_file_name, a.questioning.qtype_name )
        #end
      end
    end

    def build_answer_tree(data, form)
      response.root_node = AnswerGroup.new(
        questioning_id: response.form.root_id,
        new_rank: 0
      )
      add_level(data, form, response.root_node)
    end

    def add_level(xml_node, form_node, response_node)
      xml_node.elements.each_with_index do |child, index|
        if node_is_form_item(child)
          form_item = form_item(child.name)
          if form_item.class == QingGroup && form_item.repeatable?
            add_repeat_group(child, form_item, response_node)
          elsif form_item.class == QingGroup
            add_group(child, form_item, response_node)
          elsif form_item.multilevel?
            add_answer_set_member(child, form_item, response_node)
          else
            add_answer(child.content, form_item, response_node)
          end
        end
      end
    end

    def new_node(type, form_item, parent)
      type.new(
        questioning_id: form_item.id,
        new_rank: parent.children.length,
        inst_num: parent.new_rank + 1,
        rank: parent.children.length + 1, # for multilevel
        response_id: response.id
      )
    end

    def add_answer_set_member(xml_node, form_item, parent)
      answer_set = find_or_create_answer_set(form_item, parent)
      add_answer(xml_node.content, form_item, answer_set)
    end

    def find_or_create_answer_set(form_item, parent)
      answer_set = parent.c.find do |c|
        c.questioning_id == form_item.id && c.class == AnswerSet
      end
      if answer_set.nil?
        answer_set = new_node(AnswerSet, form_item, parent)
        parent.children << answer_set
      end
      answer_set
    end

    def add_repeat_group(xml_node, form_item, parent)
      group_set = find_or_create_group_set(form_item, parent)
      add_group(xml_node, form_item, group_set)
    end

    def find_or_create_group_set(form_item, parent)
      group_set = parent.c.find do |c|
        c.questioning_id == form_item.id && c.class == AnswerGroupSet
      end
      if group_set.nil?
        group_set = new_node(AnswerGroupSet, form_item, parent)
        parent.children << group_set
      end
      group_set
    end

    def add_group(xml_node, form_item, parent)
      unless node_is_odk_header(xml_node)
        group = new_node(AnswerGroup, form_item, parent)
        parent.children << group
        add_level(xml_node, form_item, group)
      end
    end

    def add_answer(content, form_item, parent)
      answer = new_node(Answer, form_item, parent)
      populate_answer_value(answer, content, form_item)
      parent.children << answer
    end

    def node_is_form_item(node)
      return false if node_is_odk_header(node)
      if node.name == Odk::FormDecorator::IR_QUESTION
        response.incomplete = node.content == "yes"
        return false
      end
      true
    end

    def node_is_odk_header(node)
      /\S*header/.match(node.name).present?
    end

    # finds the appropriate Option instance for an ODK submission
    def option_id_for_submission(option_node_str)
      if option_node_str =~ /\Aon([\w\-]+)\z/
        # look up inputs of the form "on####" as option node ids
        node_id = option_node_str.remove("on")
        OptionNode.id_to_option_id(node_id)
      else
        #TODO: test and failure mode?
        # look up other inputs as option ids
        Option.where(id: option_node_str).pluck(:id).first
      end
    end

    def populate_multimedia_answer(answer, pending_file_name, question_type)
      if @files[pending_file_name].present?
        answer.pending_file_name = nil
        case question_type
        when "image", "annotated_image", "sketch", "signature"
          answer.media_object = Media::Image.create(item: @files[pending_file_name])
        when "audio"
          answer.media_object = Media::Audio.create(item: @files[pending_file_name])
        when "video"
          answer.media_object = Media::Video.create(item: @files[pending_file_name])
        end
      else
        answer.value = nil
        answer.pending_file_name = pending_file_name
      end
      answer
    end

    def populate_answer_value(answer, content, form_item)
      question_type =  form_item.qtype.name
      return populate_multimedia_answer(answer, content, question_type) if form_item.qtype.multimedia?

      case question_type
      when "select_one"
        answer.option_id = option_id_for_submission(content) unless content == "none"
      when "select_multiple"
        content.split(" ").each { |oid| answer.choices.build(option_id: option_id_for_submission(oid)) } unless content == "none"
      when "date", "datetime", "time"
        # Time answers arrive with timezone info (e.g. 18:30:00.000-04), but we treat a time question
        # as having no timezone, useful for things like 'what time of day does the doctor usually arrive'
        # as opposed to 'what exact date/time did the doctor last arrive'.
        # If the latter information is desired, a datetime question should be used.
        # Also, since Rails treats time data as always on 2000-01-01, using the timezone
        # information could lead to DST issues. So we discard the timezone information for time questions only.
        # We also make sure elsewhere in the app to not tz-shift time answers when we display them.
        # (Rails by default keeps time columns as UTC and does not shift them to the system's timezone.)
        if answer.qtype.name == "time"
          content = content.gsub(/(Z|[+\-]\d+(:\d+)?)$/, "") << " UTC"
        end
        answer.send("#{answer.qtype.name}_value=", Time.zone.parse(content))
      else
        answer.value = content
      end
      answer
    end

    def form_item(name)
      form_item_id = form_item_id_from_tag(name)
      unless FormItem.exists?(form_item_id)
        raise SubmissionError.new("Submission contains unidentifiable group or question.")
      end
      form_item = FormItem.find(form_item_id)
      unless form_item.form_id == response.form.id
        raise SubmissionError.new("Submission contains group or question not found in form.")
      end
      form_item
    end

    #TODO: refactor mapping to one shared place accessible here and from odk decorators
    def form_item_id_from_tag(tag)
      prefixes = %w[qing grp]
      form_item_id = nil
      tag_without_prefix = nil
      prefixes.each do |p|
        if /#{Regexp.quote(p)}\S*/.match?(tag)
          tag_without_prefix = tag.remove p
        end
      end
      if /\S*_\d*/.match?(tag)
        form_item_id = tag_without_prefix.split("_").first
      else
        form_item_id = tag_without_prefix
      end
      form_item_id
    end

    # Checks if form ID and version were given, if form exists, and if version is correct
    def lookup_and_check_form(params)
      # if either of these is nil or not an integer, error
      raise SubmissionError.new("no form id was given") if params[:id].nil?
      raise FormVersionError.new("form version must be specified") if params[:version].nil?

      # try to load form (will raise activerecord error if not found)
      # if the response already has a form, don't fetch it again
      response.form = Form.find(params[:id]) unless response.form.present?
      form = response.form

      # if form has no version, error
      raise "xml submissions must be to versioned forms" if form.current_version.nil?

      # if form version is outdated, error
      raise FormVersionError.new("Form version is outdated") if form.current_version.code != params[:version]
    end

    def existing_response
      existing_response = Response.find_by(odk_hash: odk_hash, form_id: response.form_id)
      if existing_response.present?
        self.response = existing_response
        true
      else
        false
      end
    end

    # Generates and saves a hash of the complete XML so that multi-chunk media form submissions
    # can be uniquely identified and handled
    def odk_hash
      @odk_hash ||= Digest::SHA256.base64digest @raw_odk_xml
    end

  end
end
