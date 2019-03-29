# frozen_string_literal: true

require "rails_helper"

describe Media::Image do
  include_context "media helpers"
  include_examples "accepts file types", %w[image]
  include_examples "rejects file types", %w[audio video]
end
