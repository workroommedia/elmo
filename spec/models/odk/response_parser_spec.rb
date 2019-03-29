# frozen_string_literal: true

require "rails_helper"

describe Odk::ResponseParser do
  include_context "response tree"
  include ActionDispatch::TestProcess
  let(:save_fixtures) { true }
  let(:response) { Response.new(form: form, mission: form.mission, user: create(:user)) }
  let(:response2) { Response.new(form: form, mission: form.mission, user: create(:user)) }
  let(:xml) { prepare_odk_response_fixture(fixture_name, form, values: xml_values) }

  context "responses without media" do
    let(:form) { create(:form, :published, :with_version, question_types: question_types) }
    let(:files) { {xml_submission_file: StringIO.new(xml)} }

    context "simple form" do
      let(:fixture_name) { "simple_response" }

      context "text questions only" do
        let(:question_types) { %w[text text text] }
        let(:xml_values) { %w[A B C] }
        let(:expected_values) { xml_values }

        shared_examples "successful submission" do
          it "should produce a simple tree from a form with three children and ignore meta tag" do
            Odk::ResponseParser.new(response: response, files: files).populate_response
            expect_built_children(response.root_node, %w[Answer] * 3, form.c.map(&:id), expected_values)
          end
        end

        context "valid input" do
          it_behaves_like "successful submission"
        end

        context "outdated form" do
          let(:xml) { prepare_odk_response_fixture(fixture_name, form, values: xml_values, formver: "wrong") }

          it "should error" do
            expect do
              Odk::ResponseParser.new(response: response, files: files).populate_response
            end.to raise_error(FormVersionError, "Form version is outdated")
          end
        end

        context "missing form" do
          let(:xml) { prepare_odk_response_fixture(fixture_name, form, values: xml_values) }

          before do
            xml
            form.destroy
            response.form = nil
          end

          it "should error" do
            expect do
              Odk::ResponseParser.new(response: response, files: files).populate_response
            end.to raise_error(ActiveRecord::RecordNotFound)
          end
        end

        context "response contains form item not in form" do
          let(:other_form) { create(:form) }

          it "should error" do
            xml # create xml before updating form's second question to have a different form id.
            form.c[1].update_attribute(:form_id, other_form.id) # skip validations with update_attribute
            expect do
              Odk::ResponseParser.new(response: response, files: files).populate_response
            end.to raise_error(SubmissionError, /Submission contains group or question/)
          end
        end
      end

      context "with other question types" do
        let(:xml_values) { ["Quick", "The quick brown fox jumps over the lazy dog", 9.6] }
        let(:expected_values) { xml_values }
        let(:question_types) { %w[text long_text decimal] }

        it "processes values correctly" do
          Odk::ResponseParser.new(response: response, files: files).populate_response
          expect_built_children(response.root_node, %w[Answer] * 3, form.c.map(&:id), expected_values)
        end
      end

      context "response with select multiple" do
        let(:question_types) { %w[select_multiple select_multiple text] }
        let(:opt1) { form.c[0].option_set.sorted_children[0] }
        let(:opt2) { form.c[0].option_set.sorted_children[1] }
        let(:xml_values) { ["on#{opt1.id} on#{opt2.id}", "none", "A"] }
        let(:expected_values) { ["#{opt1.option.name};#{opt2.option.name}", nil, "A"] }

        it "should create the appropriate answer tree" do
          Odk::ResponseParser.new(response: response, files: files).populate_response
          expect_built_children(response.root_node, %w[Answer] * 3, form.c.map(&:id), expected_values)
        end
      end

      # Don't really need this spec; the hard work is in answer.rb and needs test coverage
      context "with location type" do
        let(:question_types) { %w[location location text] }
        let(:xml_values) { ["12.345600 -76.993880", "12.345600 -76.993880 123.456 20.000", "A"] }
        let(:expected_values) { xml_values }

        it "parses location answers correctly" do
          Odk::ResponseParser.new(response: response, files: files).populate_response
          expect_built_children(response.root_node, %w[Answer] * 3, form.c.map(&:id), expected_values)
        end
      end

      context "with time-related questions" do
        around do |example|
          in_timezone("Saskatchewan") { example.run } # Saskatchewan is -06
        end

        context "with date, time, and datetime types" do
          let(:question_types) { %w[datetime date time] }
          let(:datetime_str) { "2017-07-12T16:40:00.000+03" }
          let(:date_str) { "2017-07-01" }
          let(:time_str) { "14:30:00.000+03" }
          let(:xml_values) { [datetime_str, date_str, time_str] }

          it "retains timezone information for datetime but not time" do
            expected_values = [
              Time.zone.parse(datetime_str),
              Date.parse(date_str),
              # Do not retain timezone and just use UTC for time questions, since they represent time of day
              # Times without a date are 2000-01-01
              Time.zone.parse("14:30:00 UTC")
            ]
            Odk::ResponseParser.new(response: response, files: files).populate_response
            expect_built_children(response.root_node, %w[Answer] * 3, form.c.map(&:id), expected_values)
          end
        end

        context "with prefilled timestamps" do
          let(:question_types) { %w[formstart text formend] }
          let(:xml_values) { ["2017-07-12T16:40:12.000-06", "A", "2017-07-12T16:42:43.000-06"] }
          let(:expected_values) { ["2017-07-12 16:40:12 -06", "A", "2017-07-12 16:42:43 -06"] }

          it "accepts data normally" do
            Odk::ResponseParser.new(response: response, files: files).populate_response
            expect_built_children(response.root_node, %w[Answer] * 3, form.c.map(&:id), expected_values)
          end
        end
      end
    end

    context "forms with complex selects" do
      context "with complex selects" do
        let(:fixture_name) { "complex_select_response" }
        let(:question_types) { %w[select_one multilevel_select_one select_multiple] }
        let(:cat) { form.c[0].option_set.sorted_children[0] }
        let(:plant) { form.c[1].option_set.sorted_children[0] }
        let(:oak) { form.c[1].option_set.sorted_children[1] }
        let(:cat2) { form.c[2].option_set.sorted_children[0] }
        let(:dog2) { form.c[2].option_set.sorted_children[1] }
        let(:xml_values) { ["on#{cat.id}", "on#{plant.id}", "on#{oak.id}", "on#{cat2.id} on#{dog2.id}"] }

        it "parses answers" do
          Odk::ResponseParser.new(response: response, files: files).populate_response
          expect_built_children(
            response.root_node,
            %w[Answer AnswerSet Answer],
            form.c.map(&:id),
            [cat.option.name, nil, "#{cat2.option.name};#{dog2.option.name}"]
          )
          expect_built_children(
            response.root_node.c[1],
            %w[Answer Answer],
            [form.c[1].id, form.c[1].id],
            [plant.option.name, oak.option.name]
          )
        end
      end
    end

    context "forms with complex selects in a repeat group" do
      context "with complex selects" do
        let(:fixture_name) { "repeat_and_complex_select_response" }
        let(:question_types) { [{repeating: {items: %w[select_one multilevel_select_one select_multiple]}}] }
        let(:cat) { form.c[0].c[0].option_set.sorted_children[0] }
        let(:plant) { form.c[0].c[1].option_set.sorted_children[1] }
        let(:oak) { form.c[0].c[1].option_set.sorted_children[1].sorted_children[1] }
        let(:cat2) { form.c[0].c[2].option_set.sorted_children[0] }
        let(:dog2) { form.c[0].c[2].option_set.sorted_children[1] }
        let(:xml_values) { ["on#{cat.id}", "on#{plant.id}", "on#{oak.id}", "on#{cat2.id} on#{dog2.id}"] }

        it "parses answers" do
          Odk::ResponseParser.new(response: response, files: files).populate_response
          expect_built_children(
            response.root_node,
            %w[AnswerGroupSet],
            [form.c[0].id]
          )
          expect_built_children(
            response.root_node.c[0], # AnswerGroupSet
            %w[AnswerGroup],
            [form.c[0].id]
          )
          expect_built_children(
            response.root_node.c[0].c[0], # AnswerGroup
            %w[Answer AnswerSet Answer],
            form.c[0].c.map(&:id),
            [cat.option.name, nil, "#{cat2.option.name};#{dog2.option.name}"]
          )
          expect_built_children(
            response.root_node.c[0].c[0].c[1], # AnswerSet
            %w[Answer Answer],
            [form.c[0].c[1].id, form.c[0].c[1].id],
            [plant.option.name, oak.option.name]
          )
        end
      end
    end

    context "forms with a group" do
      let(:question_types) { ["text", %w[text text], "text"] }
      let(:fixture_name) { "group_form_response" }
      let(:xml_values) { %w[A B C D] }

      it "should produce the correct tree" do
        Odk::ResponseParser.new(response: response, files: files).populate_response
        expect_built_children(response.root_node, %w[Answer AnswerGroup Answer],
          form.c.map(&:id), ["A", nil, "D"])
        expect_built_children(response.root_node.c[1], %w[Answer Answer], form.c[1].c.map(&:id), %w[B C])
      end
    end

    context "repeat group forms" do
      let(:fixture_name) { "repeat_group_form_response" }
      let(:question_types) { ["text", {repeating: {items: %w[text text]}}] }
      let(:xml_values) { %w[A B C D E] }

      it "should create the appropriate repeating group tree" do
        Odk::ResponseParser.new(response: response, files: files).populate_response
        expect_built_children(response.root_node, %w[Answer AnswerGroupSet], form.c.map(&:id), ["A", nil])
        expect_built_children(response.root_node.c[1],
          %w[AnswerGroup AnswerGroup],
          [form.c[1].id, form.c[1].id],
          [nil, nil])
        expect_built_children(response.root_node.c[1].c[0], %w[Answer Answer], form.c[1].c.map(&:id), %w[B C])
        expect_built_children(response.root_node.c[1].c[1], %w[Answer Answer], form.c[1].c.map(&:id), %w[D E])
      end
    end

    context "form with nexted groups" do
      let(:question_types) do
        [
          "integer",
          {repeating:
            {items: [
              "integer",
              {repeating: {items: %w[integer integer]}}
            ]}}
        ]
      end
      let(:fixture_name) { "nested_group_form_response" }
      let(:xml_values) { [*1..9] }

      it "should create nested tree" do
        Odk::ResponseParser.new(response: response, files: files).populate_response
        expect_built_children(response.root_node, %w[Answer AnswerGroupSet], form.c.map(&:id), [1, nil])
        expect_built_children(response.root_node.c[1],
          %w[AnswerGroup AnswerGroup],
          [form.c[1].id, form.c[1].id])
        parent_group_set = response.root_node.c[1]
        child_group_set1 = parent_group_set.c[0].c[1]
        expect_built_children(parent_group_set.c[0],
          %w[Answer AnswerGroupSet],
          form.c[1].c.map(&:id),
          [2, nil])
        expect_built_children(child_group_set1.c[0],
          %w[Answer Answer],
          form.c[1].c[1].c.map(&:id),
          [3, 4])
        expect_built_children(child_group_set1.c[1],
          %w[Answer Answer],
          form.c[1].c[1].c.map(&:id),
          [5, 6])
        expect_built_children(child_group_set1.c[1],
          %w[Answer Answer],
          form.c[1].c[1].c.map(&:id),
          [5, 6])
        child_group_set2 = parent_group_set.c[1].c[1]
        expect_built_children(parent_group_set.c[1],
          %w[Answer AnswerGroupSet],
          form.c[1].c.map(&:id),
          [7, nil])
        expect_built_children(child_group_set2.c[0],
          %w[Answer Answer],
          form.c[1].c[1].c.map(&:id),
          [8, 9])
      end
    end

    context "form with multilevel answer" do
      let(:question_types) { %w[text multilevel_select_one multilevel_select_one multilevel_select_one] }
      let(:level1_opt) { form.c[1].option_set.sorted_children[1] }
      let(:level2_opt) { form.c[1].option_set.sorted_children[1].sorted_children[0] }
      let(:fixture_name) { "multilevel_response" }
      let(:xml_values) do
        ["A",
         "on#{level1_opt.id}",
         "on#{level2_opt.id}",
         "",
         "",
         "on#{level1_opt.id}",
         ""]
      end
      let(:expected_values) do
        ["A",
         level1_opt.option.name,
         level2_opt.option.name,
         nil,
         nil,
         level1_opt.option.name,
         nil]
      end

      it "should create the appropriate multilevel answer tree" do
        Odk::ResponseParser.new(response: response, files: files).populate_response
        expect_built_children(
          response.root_node,
          %w[Answer AnswerSet AnswerSet AnswerSet],
          form.c.map(&:id),
          [expected_values.first, nil, nil, nil]
        )
        expect_built_children(
          response.root_node.c[1],
          %w[Answer Answer],
          [form.c[1].id, form.c[1].id],
          expected_values[1, 2]
        )
        expect_built_children(
          response.root_node.c[2],
          %w[Answer Answer],
          [form.c[2].id, form.c[2].id],
          [nil, nil]
        )
        expect_built_children(
          response.root_node.c[3],
          %w[Answer Answer],
          [form.c[3].id, form.c[3].id],
          expected_values[5, 6]
        )
      end
    end
  end

  context "responses with media" do
    let(:fixture_name) { "simple_response" }
    let(:form) { create(:form, :published, :with_version, question_types: question_types) }

    context "single part media" do
      let(:media_file_name) { "the_swing.jpg" }
      let(:image) { fixture_file_upload(media_fixture("images/#{media_file_name}"), "image/jpeg") }
      let(:question_types) { %w[text text text image] }
      let(:files) { {xml_submission_file: StringIO.new(xml), media_file_name => image} }
      let(:xml_values) { ["A", "B", "C", media_file_name] }

      it "creates response tree with media object for media answer" do
        Odk::ResponseParser.new(response: response, files: files).populate_response
        expect(response.root_node.c[3].media_object.item_file_name).to include(media_file_name)
      end
    end

    context "multipart media with one mixture of valid and invalid file types" do
      let(:media_file_name_1) { "the_swing.jpg" }
      let(:media_file_name_2) { "another_swing.jpg" }
      let(:media_file_name_3) { "not_an_image.ogg" }
      let(:image_1) { media_fixture("images/#{media_file_name_1}") }
      let(:image_2) { media_fixture("images/#{media_file_name_2}") }
      let(:image_3) { media_fixture("images/#{media_file_name_3}") }
      let(:question_types) { %w[text image image image] }
      let(:request1_files) do
        {
          xml_submission_file: StringIO.new(xml),
          media_file_name_1 => image_1
        }
      end
      let(:request2_files) do
        {
          xml_submission_file: StringIO.new(xml),
          media_file_name_2 => image_2,
          media_file_name_3 => image_3
        }
      end
      let(:xml_values) { ["A", media_file_name_1, media_file_name_2, media_file_name_3] }

      it "creates response tree with media object for media answer and discards file with invalid type" do
        # First request
        populated = Odk::ResponseParser.new(response: response, files: request1_files,
                                            awaiting_media: true).populate_response
        populated.save!
        expect(Response.count).to eq(1)
        expect(populated.root_node.c.count).to eq(4)
        expect(populated.root_node.c[1].pending_file_name).to be_nil
        expect(populated.root_node.c[1].media_object.item_file_name).to include(media_file_name_1)
        expect(populated.root_node.c[2].pending_file_name).to eq(media_file_name_2)
        expect(populated.root_node.c[2].media_object).to be_nil

        # Second request
        # Use a different response object (response2) to simulate what would happen
        # in the controller in a separate request.
        # Note that in this case ResponseParser returns a different response object than what it receives.
        populated = Odk::ResponseParser.new(response: response2, files: request2_files,
                                            awaiting_media: false).populate_response
        populated.save!
        expect(Response.count).to eq(1)
        populated.reload
        expect(populated.root_node.c[2].media_object.item_file_name).to include(media_file_name_2)
        expect(populated.root_node.c[3].media_object).to be_nil
      end
    end
  end

  def prepare_odk_response_fixture(fixture_name, form, options = {})
    prepare_odk_fixture(name: fixture_name, type: :response, form: form, **options)
  end
end
