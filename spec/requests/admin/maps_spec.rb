require 'rails_helper'

RSpec.describe "Admin::Maps", type: :request do
  let(:user) { create(:user) }
  let!(:blog) { Blog.first || create(:blog) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
  let(:photo) { entry.photos.first }

  before do
    sign_in_as(user)
    attach_image_to_photo(photo)
    photo.update!(latitude: 40.7128, longitude: -74.0060)
  end

  describe "GET /admin/map (index)" do
    it "renders successfully" do
      get admin_map_path
      expect(response).to have_http_status(:success)
    end

    it "displays map page title" do
      get admin_map_path
      expect(response.body).to include("Map")
    end
  end

  describe "GET /admin/map/photos" do
    it "renders JSON successfully" do
      get admin_map_markers_path(format: :json)
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include('application/json')
    end
  end

  describe "GET /admin/map/photo/:id" do
    it "renders JSON for a specific photo" do
      get admin_map_photo_path(photo, format: :json)
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include('application/json')
    end

    it "returns 404 for non-existent photo" do
      get admin_map_photo_path(id: 999999, format: :json)
      expect(response).to have_http_status(:not_found)
    end
  end
end
