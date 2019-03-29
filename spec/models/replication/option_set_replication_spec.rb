# frozen_string_literal: true

require "rails_helper"

describe OptionSet do
  let(:mission1) { create(:mission) }
  let(:mission2) { create(:mission) }

  describe "to_mission" do
    let(:orig) { create(:option_set, option_names: :multilevel, is_standard: true) }
    let(:copy) { orig.replicate(mode: :to_mission, dest_mission: mission2) }

    it "should be copied properly" do
      expect(copy.mission).to eq(mission2)
      expect(copy.name).to eq(orig.name)
      expect(copy.standard).to eq(orig)
      expect(copy.is_standard).to eq(false)
      expect(copy.total_options).to eq(6)

      # Ensure options are correct.
      expect(copy.c[0].option.name).to eq(orig.c[0].option.name)
      expect(copy.c[0].c[0].option.name).to eq(orig.c[0].c[0].option.name)

      # Ensure ancestry is correct.
      expect(copy.root_node.parent).to be_nil
      expect(copy.c[0].parent).to eq(copy.root_node)
      expect(copy.c[0].c[0].parent).to eq(copy.c[0])

      # Ensure option set gets correct root node id.
      expect(copy.root_node_id).not_to be_nil
      expect(copy.root_node_id).not_to eq(orig.root_node_id)

      # Ensure option set ID gets copied all the way down.
      expect(copy.root_node.option_set_id).to eq(copy.id)
      expect(copy.root_node.c[0].option_set_id).to eq(copy.id)
      expect(copy.root_node.c[0].c[0].option_set_id).to eq(copy.id)

      # Ensure option nodes get correct attributes
      expect(copy.root_node.c[0].is_standard).to be(false)
      expect(copy.root_node.c[0].c[0].is_standard).to be(false)
      expect(copy.root_node.c[0].standard_copy).to be(true)
      expect(copy.root_node.c[0].c[0].standard_copy).to be(true)

      # Ensure option nodes get correct original references
      expect(copy.root_node.c[0].original_id).to eq(orig.root_node.c[0].id)
      expect(copy.root_node.c[0].c[0].original_id).to eq(orig.root_node.c[0].c[0].id)
      expect(copy.root_node.c[0].original).to eq(orig.root_node.c[0])
      expect(copy.root_node.c[0].c[0].original).to eq(orig.root_node.c[0].c[0])

      # Ensure no duplicates.
      expect(Option.count).to eq(12)
      expect(OptionNode.count).to eq(14)
    end

    context "when replicating directly and copy exists in mission" do
      let(:copy2) { orig.replicate(mode: :to_mission, dest_mission: mission2) }

      it "should make new copy but reuse options" do
        expect(copy2).not_to eq(copy)
        expect(copy2.options).to eq(copy.options)
      end
    end
  end

  describe "promote with link" do
    let(:orig) { create(:option_set, option_names: :multilevel, mission: mission1) }
    let(:copy) { orig.replicate(mode: :promote) }

    it "should create a correct copy" do
      expect(copy.mission).to be_nil
      expect(copy.is_standard).to eq(true)
      expect(copy.original).to eq(orig)
      expect(copy.total_options).to eq(6)
      expect(copy.options).not_to eq(orig.options)
    end
  end

  describe "clone" do
    let(:orig) { create(:option_set, option_names: :multilevel, mission: mission1) }
    let(:copy) { orig.replicate(mode: :clone) }

    it "should make correct copy" do
      expect(copy.mission).to eq(mission1)
      expect(copy.is_standard).to eq(false)
      expect(copy.original).to eq(orig)
      expect(copy.total_options).to eq(6)
      expect(copy.options).to eq(orig.options)

      # Ensure options are correct.
      expect(copy.c[0].option.name).to eq(orig.c[0].option.name)
      expect(copy.c[0].c[0].option.name).to eq(orig.c[0].c[0].option.name)

      # Ensure ancestry is correct.
      expect(copy.root_node.parent).to be_nil
      expect(copy.c[0].parent).to eq(copy.root_node)
      expect(copy.c[0].c[0].parent).to eq(copy.c[0])

      # Ensure option set gets correct root node id.
      expect(copy.root_node_id).not_to be_nil
      expect(copy.root_node_id).not_to eq(orig.root_node_id)

      # Ensure option set ID gets copied all the way down.
      expect(copy.root_node.option_set_id).to eq(copy.id)
      expect(copy.root_node.c[0].option_set_id).to eq(copy.id)
      expect(copy.root_node.c[0].c[0].option_set_id).to eq(copy.id)

      # Ensure option nodes get correct attributes
      expect(copy.root_node.c[0].is_standard).to be(false)
      expect(copy.root_node.c[0].c[0].is_standard).to be(false)
      expect(copy.root_node.c[0].standard_copy).to be(false)
      expect(copy.root_node.c[0].c[0].standard_copy).to be(false)

      # Ensure option nodes get correct original references
      expect(copy.root_node.c[0].original_id).to eq(orig.root_node.c[0].id)
      expect(copy.root_node.c[0].c[0].original_id).to eq(orig.root_node.c[0].c[0].id)
      expect(copy.root_node.c[0].original).to eq(orig.root_node.c[0])
      expect(copy.root_node.c[0].c[0].original).to eq(orig.root_node.c[0].c[0])

      # Ensure no duplicates (options are not duplicated in :clone mode)
      expect(Option.count).to eq(6)
      expect(OptionNode.count).to eq(14)
    end
  end
end
