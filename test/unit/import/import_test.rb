require 'test_helper'

class Import::ImportTest < ActiveSupport::TestCase

####################################################################################################
# Import Initialization
####################################################################################################
  test "import requires a mission" do
    assert_raise ArgumentError do
      create_import(:dest_mission => nil)
    end
  end

  test "import requires data to import" do
    assert_raise ArgumentError do
      create_import(:dest_mission => get_mission)
    end
  end

  test "import requires a mission and data to import" do
    assert_nothing_raised do
      create_import(:dest_mission => get_mission, :import_data => FactoryGirl.build(:form).as_json)
    end
  end

####################################################################################################
# Import
####################################################################################################
  test "importing form data should also create two questions" do
    import_data = import_file('big_form')

    old_questioning_count = Questioning.all.count
    #add_questioning_count = f.questionings.count

    old_question_count    = Question.all.count
    #add_question_count    = f.questions.count

    old_option_set_count    = OptionSet.all.count
    #add_option_set_count    = f.option_sets.count

    create_import(:dest_mission => FactoryGirl.create(:mission, :name => "import mission"), :import_data => import_data)

    @import.import_data

    #assert_questioning_created(old_questioning_count, add_questioning_count)
    #assert_questions_created(old_question_count, add_question_count)
    #assert_option_sets_created(old_option_set_count, add_option_set_count)
  end

  test "import of form should create new objects" do
    f = FactoryGirl.create(:form, :question_types => %w(select_one integer), :is_standard => false)
    r = Replication.new(:mode => :export, :src_obj => f)
    export = f.json_for_export(r)

    old_forms_count       = Form.all.count

    old_questioning_count = Questioning.all.count
    add_questioning_count = f.questionings.count

    old_question_count    = Question.all.count
    add_question_count    = f.questions.count

    old_option_set_count    = OptionSet.all.count
    add_option_set_count    = f.option_sets.count

    create_import(:dest_mission => FactoryGirl.create(:mission, :name => "import mission"), :import_data => export)

    @import.import_data
    assert_equal(Form.all.count, old_forms_count + 1)
    assert_questioning_created(old_questioning_count, add_questioning_count)
    assert_questions_created(old_question_count, add_question_count)
    assert_option_sets_created(old_option_set_count, add_option_set_count)
  end

####################################################################################################
# Private
####################################################################################################
  private
    def assert_questioning_created(old_count, add_count)
      assert(add_count > 0, 'test should have new questionings')
      assert_equal(Questioning.all.count, old_count + add_count)
    end
    def assert_questions_created(old_count, add_count)
      assert(add_count > 0, 'test should have new questions')
      assert_equal(Question.all.count, old_count + add_count)
    end
    def assert_option_sets_created(old_count, add_count)
      assert(add_count > 0, 'test should have new option sets')
      assert_equal(OptionSet.all.count, old_count + add_count)
    end

    def create_import(options)
      mission = options[:dest_mission]# ? options[:mission] : get_mission
      @import = Import::Import.new(:dest_mission => mission, :import_data => options[:import_data])
    end

    def import_file(filename)
      # write xml to file
      require 'fileutils'
      FileUtils.mkpath('test/fixtures')
      fixture_file = Rails.root.join('test/fixtures/', "#{filename}.import")
      import_data = File.open(fixture_file.to_s, 'r') do |f|
        f.read
        #JSON.load(f)
      end
      JSON.parse import_data
    end

end
