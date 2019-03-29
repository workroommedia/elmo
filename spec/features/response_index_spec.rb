# frozen_string_literal: true

require "rails_helper"

feature "response index", js: true do
  include_context "search"
  include_context "batch delete"
  let(:admin) { create(:admin) }
  let(:mission) { get_mission }

  before do
    login(admin)
  end

  describe "bulk destroy not paginated" do
    let!(:responses) { create_list(:response, 5, mission: mission) }

    context "unfiltered" do
      let!(:preserved_obj) { nil }
      it_behaves_like "select all on page", link: "Delete Selected", klass: "responses", num: 5
    end

    context "filtered" do
      before do
        Response.last.update!(reviewed: true)
      end
      let!(:preserved_obj) { Response.first.shortcode.upcase }
      it_behaves_like "select all on page", link: "Delete Selected", klass: "responses", num: 1,
                                            query: "reviewed:1"
    end

    context "select nothing" do
      it_behaves_like "select nothing", "responses", "Delete Selected"
    end
  end

  describe "bulk destroy paginated" do
    let!(:responses) do
      [
        create(:response, created_at: Time.current - 1.day, mission: mission, reviewed: true),
        create(:response, created_at: Time.current - 2.days, mission: mission, reviewed: true),
        create(:response, created_at: Time.current - 3.days, mission: mission, reviewed: true),
        create(:response, created_at: Time.current - 4.days, mission: mission, reviewed: true),
        create(:response, created_at: Time.current - 5.days, mission: mission, reviewed: true)
      ]
    end
    let!(:responses_un) do
      [
        create(:response, created_at: Time.current - 6.days, mission: mission),
        create(:response, created_at: Time.current - 7.days, mission: mission),
        create(:response, created_at: Time.current - 8.days, mission: mission),
        create(:response, created_at: Time.current - 9.days, mission: mission),
        create(:response, created_at: Time.current - 10.days, mission: mission)
      ]
    end

    before do
      stub_const(ResponsesController, "PER_PAGE", 2)
    end

    context "unfiltered select page" do
      let!(:preserved_obj) { responses[2].shortcode.upcase }
      it_behaves_like "select all on page", link: "Delete Selected", klass: "responses", num: 2
    end

    context "unfiltered select all" do
      let!(:preserved_obj) { nil }
      it_behaves_like "select all that exist", klass: "responses", num: 10, link: "Delete Selected"
    end

    context "filtered select all" do
      let!(:preserved_obj) { nil }
      it_behaves_like "select all that exist", klass: "responses", num: 5,
                                               link: "Delete Selected", query: "reviewed:1"
    end
  end
end
