# import form/option set/etc information
#
# input: json representation of the import models and mission we want to import into
class Import::Import

  # hold values for translating import id to new model id { model_id-<id value> => new_model_id }
  #   example: {"form_id-240312"=>240352, "question_id-241122"=>241138}
  attr_accessor :translation_map

  # mission we are importing into
  attr_accessor :dest_mission

  # required parameters:
  # :dest_mission - mission we are importing into
  # :import_data - data to be imported into the system
  def initialize(options={})
    # set the destination mission
    raise ArgumentError, 'Destination mission has not been defined repond to' unless options.respond_to?("[]") && options[:dest_mission]
    if options[:dest_mission].is_a?(Mission)
      @dest_mission = options[:dest_mission]
    else
      @dest_mission = Mission.find(options[:dest_mission])
    end

    # initialize translation map
    @translation_map = {}

    raise ArgumentError, 'Data to be imported has not been specified' unless options.respond_to?("[]") && options[:import_data]
    @import_data = options[:import_data]
  end

  # main method for importing data into the system
  # * entire process is executed in a transaction. if there are any errors, nothing will be saved
  def import_data
    ActiveRecord::Base.transaction do
      # import all Options first. This makes working with option sets easier
      @import_data.select{|json| json.keys.first == "option"}.each do |json_object|
        setup_and_create_new_object(json_object)
      end
      @import_data.delete_if{|json| json.keys.first == "option"}

      # import all OptionSets and a single required Optioning
      @import_data.select{|json| json.keys.first == "option_set"}.each do |json_object|
        setup_and_create_new_option_set(json_object)
      end
      @import_data.delete_if{|json| json.keys.first == "option_set"}

      # import all other data
      @import_data.each do |json_object|
        setup_and_create_new_object(json_object)
      end
    end
  end


  # for each line of data, we need to determine:
  # * the model and content,
  # * check if the model has already been imported
  #   * if it has not, create the new model and map the new model id into the translation map
  def setup_and_create_new_object(json_object)
    model_name, content = setup_model_name_and_content(json_object)

    #create_new_object(model_name, content) unless @translation_map["#{model_name}_id-#{content["id"]}"]
    create_new_object(model_name, content) unless find_model_in_translation_map(model_name, content["id"])
  end

  # for each line of data, we need to determine:
  # * the model we are working with, and
  # * the content used to create the model
  def setup_model_name_and_content(json_object)
    model_name = json_object.keys.first
    content    = json_object[model_name]
    return model_name, content
  end

  # create a new object for an import model
  #
  # params: model - we are trying to create
  # params: content - content we are populating the model with
  def create_new_object(model_name, content)
    # before we create the object, we need to create all the sub-objects first.
    # this will result in new content as object ids are translated to new object ids
    content = create_relationship_objects(content)
    new_model = build_new_object(model_name, content)

    raise ImportError, "#{model_name} could not save. #{new_model.errors.inspect}" unless new_model.save

    update_translation_map(model_name, content["id"], new_model.id)

    new_model
  end

  # build a new object for an import model. does not save the model!
  def build_new_object(model_name, content)
    content.merge!(:mission_id => @dest_mission.id)
    new_model = model_name.camelize.constantize.new(content)
    if params = new_model.replicable_opts(:uniqueness)
      params = params.merge(:mission => @dest_mission, :dest_obj => new_model)
      # get a unique field value (e.g. name) for the dest_obj (may be the same as the source object's value)
      unique_field_val = new_model.generate_unique_field_value(params)

      # set the value on the dest_obj
      new_model.send("#{params[:field]}=", unique_field_val)
    end

    new_model
  end

  # if there are relationships with other objects, we need to handle them by either:
  #   * creating new objects, or
  #   * translate the import id to the id of an object we already created
  def create_relationship_objects(content)
    # for a given model, look at the relationships with other objects it has by looking for fields with "id"
    find_relationships(content).each do |relationship_model|
      relationship_model_value = content[relationship_model]

      is_ref_qing = true if relationship_model == "ref_qing_id"
      model_lookup = is_ref_qing ? "questioning_id" : relationship_model # what model to use when looking up translation values

      model_id = find_model_in_translation_map(model_lookup, relationship_model_value) # look if the object already exists
      if model_id # update content with destination system model id
        content[relationship_model] = model_id
      else # we need to create a new object
        new_object_json = find_entry_in_import_data(model_lookup, content[relationship_model])
        raise ImportError, "missing import data for #{relationship_model} #{content[relationship_model]}" unless new_object_json

        # create new object before we move on to create the main object
        new_object = setup_and_create_new_object(new_object_json)

        # update object json with new id from newly created object
        content[relationship_model] = new_object.id
      end
    end
    content
  end


  # look for relationships to other objects
  #
  # sample data: {"form_id"=>240312, "hidden"=>false, "id"=>241641, "rank"=>1, "required"=>false}
  # result: ["form_id"]
  def find_relationships(object)
    keys = object.keys

    # find the data with _id in the name. we are going to need to do a translation lookup on them
    id_keys = keys.select{|key| /_id$/.match(key)}
    id_keys.delete_if { |k| object[k].nil? }        # Remove _id's that have no relationships with another object

    id_keys
  end

  # find data to an object, so it can be created ahead of time.
  def find_entry_in_import_data(model, model_id)
    model = model.to_s.gsub(/_id$/, "")  # remove the trailing _id if it's present

    @import_data.each do |json_object|
      return json_object if json_object[model] && json_object[model]["id"] == model_id
    end
    nil
  end

  # find new model id in translation map
  #
  # input: "form_id", 240312
  # output: 13                   # 240312 was the original, 13 is the new id
  # output: nil                  # match could not be found, a new object needs to be created
  def find_model_in_translation_map(model_id, model_id_value)
    model_id = "#{model_id}_id" unless model_id.match(/_id$/)
    translation_key = "#{model_id}-#{model_id_value}"

    # do we have the model_id in our system
    if @translation_map[translation_key]
      @translation_map[translation_key]
    else
      nil
    end
  end

####################################################################################################
# BEGIN: OptionSet Specific Code
####################################################################################################
  def setup_and_create_new_option_set(json_object)
    model_name, content = setup_model_name_and_content(json_object)

    create_new_option_set(model_name, content) unless find_model_in_translation_map(model_name, content["id"])
  end

  # We need to make a relationship with Optioning before OptionSet will save
  def create_new_option_set(model_name, content)
    new_option_set = build_new_object(model_name, content)

    import_option_set_id = content["id"]

    # find optioning for the option_set
    import_optioning_id, new_optioning = build_new_optioning(import_option_set_id)

    new_option_set.optionings = [new_optioning]

    raise ImportError, "#{model} could not save. #{new_model.errors.inspect}" unless new_option_set.save
    update_translation_map(model_name, content["id"], new_option_set.id)

    update_translation_map("optioning", import_optioning_id, new_optioning.id)
  end

  def build_new_optioning(import_option_set_id)
    @import_data.select{|json| json.keys.first == "optioning"}.each do |json_object|
      optioning_model_name, optioning_content = setup_model_name_and_content(json_object)

      # check if it matches the OptionSet id
      if optioning_content["option_set_id"] == import_option_set_id
        optioning_id = optioning_content["id"]
        optioning_content.delete("option_set_id")
        optioning_content = create_relationship_objects(optioning_content)
        return optioning_id, build_new_object(optioning_model_name, optioning_content)
      end
    end
  end

####################################################################################################
# END: OptionSet Specific Code
####################################################################################################


  # update translation map with a models new id value
  def update_translation_map(model_name_id, old_id_value, new_id_value)
    model_name_id = model_name_id + "_id" unless model_name_id.match(/_id%/)

    translation_key = "#{model_name_id}-#{old_id_value}"

    @translation_map[translation_key] = new_id_value
  end

end
