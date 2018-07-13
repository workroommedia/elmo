# frozen_string_literal: true

require "rails_helper"

describe Odk::CodeMapper do
  let(:form) { create(:form, question_types: ["text", %w[text text], "multilevel_select_one"]) }
  let(:mapper) { Odk::CodeMapper.new }

  context "item_id_for_code" do
    it "retrieves group for group code" do
      group = form.c[1]
      code = "grp#{group.id}"
      expect(mapper.item_id_for_code(code, form)).to eq group.id
    end

    it "retrieves questioning for questioning with code starting with qing" do
      form_item = form.c[0]
      code = "qing#{form_item.id}"
      expect(mapper.item_id_for_code(code, form)).to eq form_item.id
    end

    it "retrieves correct questioning when it receives old style q{question.id} code" do
      other_form = create(:form, question_types: ["text", %w[text text]])
      other_form.c[0].update_attribute(:question_id, form.c[0].question_id)
      assert form.c[0].question_id == other_form.c[0].question_id
      form_item = form.c[0]
      code = "q#{form_item.question.id}"
      expect(mapper.item_id_for_code(code, form)).to eq form_item.id
    end

    it "handles multilevel codes" do
      multilevel_qing = form.c[2]
      codes = multilevel_qing.subqings.map { |sq| Odk::SubqingDecorator.decorate(sq).odk_code }
      puts "codes: #{codes}"
      codes.each do |c|
        expect(mapper.item_id_for_code(c, form)).to eq multilevel_qing.id
      end
    end

    it "errors when code has unknown format" do
      code = "group123"
      expect do
        mapper.item_id_for_code(code, form)
      end.to raise_error(SubmissionError, "Code format unknown: #{code}.")
    end
  end
end
