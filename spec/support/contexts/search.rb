# frozen_string_literal: true

shared_context "search" do
  def search_for(query)
    fill_in("search", with: query)
    click_button("Search")
  end

  def expect_matches(matching, but_not: [])
    Array.wrap(matching).each { |m| expect(page).to have_content(m) }
    Array.wrap(but_not).each { |m| expect(page).not_to have_content(m) }
  end
end
