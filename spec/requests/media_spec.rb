require 'rails_helper'

RSpec.describe "Media", type: :request do
  let!(:blog) { Blog.first || create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
  let(:photo) { entry.photos.first }

  before do
    attach_image_to_photo(photo)
  end

  describe "GET /photos/:photo_id/media/:style" do
    it "redirects to the instagram thumbor URL" do
      get photo_media_path(photo_id: photo.id, style: 'instagram')
      expect(response).to have_http_status(:redirect)
      expect(response.location).to eq(photo.instagram_url)
    end

    it "redirects to the threads thumbor URL" do
      get photo_media_path(photo_id: photo.id, style: 'threads')
      expect(response).to have_http_status(:redirect)
      expect(response.location).to eq(photo.threads_url)
    end

    it "redirects to the instagram story thumbor URL" do
      get photo_media_path(photo_id: photo.id, style: 'instagram_story')
      expect(response).to have_http_status(:redirect)
      expect(response.location).to eq(photo.instagram_story_url)
    end

    it "redirects to the cropped instagram story thumbor URL" do
      get photo_media_path(photo_id: photo.id, style: 'instagram_story', crop: 'true')
      expect(response).to have_http_status(:redirect)
      expect(response.location).to eq(photo.instagram_story_url(crop: true))
    end

    it "returns 404 for an invalid style" do
      expect {
        get photo_media_path(photo_id: photo.id, style: 'invalid')
      }.to raise_error(ActionController::RoutingError)
    end

    it "returns 404 for a non-existent photo" do
      expect {
        get photo_media_path(photo_id: 0, style: 'instagram')
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
