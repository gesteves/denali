require 'rails_helper'

RSpec.describe "Sitemaps", type: :request do
  let!(:blog) { Blog.first || create(:blog) }
  let(:user) { create(:user) }
  let!(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }

  before do
    entry.photos.each { |p| attach_image_to_photo(p) }
  end

  describe "GET /sitemap.xml (index)" do
    it "renders successfully" do
      get sitemap_path(format: :xml)
      expect(response).to have_http_status(:success)
    end

    it "returns XML content type" do
      get sitemap_path(format: :xml)
      expect(response.content_type).to include("application/xml")
    end
  end

  describe "GET /sitemap/entries/:page.xml" do
    it "renders successfully" do
      get entries_sitemap_path(page: 1, format: :xml)
      expect(response).to have_http_status(:success)
    end

    it "returns XML content type" do
      get entries_sitemap_path(page: 1, format: :xml)
      expect(response.content_type).to include("application/xml")
    end

    it "returns 404 for invalid page" do
      get entries_sitemap_path(page: 9999, format: :xml)
      expect(response).to have_http_status(:not_found)
    end
  end
end
