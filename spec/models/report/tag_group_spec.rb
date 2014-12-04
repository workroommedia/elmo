require 'spec_helper'

describe Report::TagGroup do
  describe '::generate' do
    before do
      @tag1 = create(:tag, name: 'b')
      @tag2 = create(:tag, name: 'a')
      @q1 = create(:question, tags: [@tag1])
      @q2 = create(:question, tags: [@tag2])
      @qing1 = create(:questioning, question: @q1)
      @qing2 = create(:questioning, question: @q2)
      @qing3 = create(:questioning)
      @summaries = [
        double('summary 1', questioning: @qing1, headers: []).as_null_object,
        double('summary 2', questioning: @qing2, headers: []).as_null_object,
        double('summary 3', questioning: @qing3, headers: []).as_null_object,
      ]
    end

    it "should return summaries grouped by tag" do
      options = { group_by_tag: true, question_order: 'number' }
      tag_groups = Report::TagGroup.generate(@summaries, options)
      expect(tag_groups).to be_a Array
      expect(tag_groups.first).to be_a Report::TagGroup
      # Ordered by tag with untagged at the end
      expect(tag_groups.map(&:tag)).to eq [@tag2, @tag1, :untagged]
      expect(tag_groups.map{|t| t.type_groups.map(&:summaries)}.flatten).to eq [@summaries[1], @summaries[0], @summaries[2]]
    end

    it "should return one big group when not grouped by tag" do
      options = { group_by_tag: false, question_order: 'number' }
      tag_groups = Report::TagGroup.generate(@summaries, options)
      expect(tag_groups).to be_a Array
      expect(tag_groups.count).to eq 1
      expect(tag_groups.first).to be_a Report::TagGroup
      expect(tag_groups.first.tag).to be_nil
    end
  end
end
