require 'rails_helper'

RSpec.describe "Oembed", type: :request do
  let!(:blog) { Blog.first || create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
  let(:photo) { entry.photos.first }

  before do
    attach_image_to_photo(photo)
  end

  describe "GET /oembed" do
    let(:entry_full_url) { "http://localhost:3000#{entry_long_path(entry)}" }

    it "renders JSON with correct response body" do
      get "/oembed.json", params: { url: entry_full_url }
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("application/json")
      json = JSON.parse(response.body)
      expect(json["type"]).to eq("photo")
      expect(json["version"]).to eq("1.0")
      expect(json["title"]).to eq(entry.plain_title)
      expect(json["author_name"]).to eq(user.name)
      expect(json["url"]).to be_present
      expect(json["width"]).to be_a(Integer)
      expect(json["height"]).to be_a(Integer)
      expect(json["thumbnail_url"]).to be_present
      expect(json["thumbnail_width"]).to be_a(Integer)
      expect(json["thumbnail_height"]).to be_a(Integer)
    end

    it "renders XML with correct root element" do
      get "/oembed.xml", params: { url: entry_full_url }
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("application/xml")
      expect(response.body).to include("<oembed>")
      expect(response.body).not_to include("<ombed>")
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

    it "returns 404 for an entry without photos" do
      entry.photos.destroy_all
      entry.reload
      get "/oembed.json", params: { url: entry_full_url }
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for an invalid URL" do
      get "/oembed.json", params: { url: "http://localhost:3000/nonexistent/path" }
      expect(response).to have_http_status(:not_found)
    end
  end
end
