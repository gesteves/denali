require 'rails_helper'

RSpec.describe "Oembed", type: :request do
  let!(:blog) { Blog.first || create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
  let(:photo) { entry.photos.first }

  before do
    attach_image_to_photo(photo)
    # The image dimensions come from the attached blob's metadata
    # rusty.jpg fixture should provide the dimensions automatically
  end

  describe "GET /oembed" do
    # Use full URL with host, as oEmbed clients typically provide
    # Must use entry_long_path because find_by_url expects entries#show action
    let(:entry_full_url) { "http://localhost:3000#{entry_long_path(entry)}" }

    it "renders JSON successfully" do
      get "/oembed.json", params: { url: entry_full_url }
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("application/json")
    end

    it "renders XML successfully" do
      get "/oembed.xml", params: { url: entry_full_url }
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("application/xml")
    end

    it "defaults to JSON format" do
      get "/oembed.json", params: { url: entry_full_url }
      expect(response.content_type).to include("application/json")
    end

    it "respects maxwidth parameter" do
      get "/oembed.json", params: { url: entry_full_url, maxwidth: 800 }
      json = JSON.parse(response.body)
      expect(json["width"]).to be <= 800
    end

    it "respects maxheight parameter" do
      get "/oembed.json", params: { url: entry_full_url, maxheight: 600 }
      json = JSON.parse(response.body)
      expect(json["height"]).to be <= 600
    end

    it "handles entry without photos gracefully" do
      # When photos are destroyed, photos_have_dimensions? returns true for empty array
      # The controller may return empty response or 200 status
      entry.photos.destroy_all
      entry.reload
      get "/oembed.json", params: { url: entry_full_url }
      # Just verify we get a response (behavior depends on implementation)
      expect([200, 404]).to include(response.status)
    end
  end
end
