require 'rails_helper'

RSpec.describe "Media", type: :request do
  let!(:blog) { Blog.first || create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
  let(:photo) { entry.photos.first }
  let(:image_body) { File.read(Rails.root.join('spec/fixtures/images/rusty.jpg'), mode: 'rb') }

  before do
    attach_image_to_photo(photo)
    stub_request(:get, /#{ENV['THUMBOR_DOMAIN']}/).to_return(
      status: 200,
      body: image_body,
      headers: { 'Content-Type' => 'image/jpeg' }
    )
  end

  describe "GET /photos/:photo_id/media/:style" do
    it "serves the instagram image" do
      get photo_media_path(photo_id: photo.id, style: 'instagram')
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('image/jpeg')
      expect(response.body).to eq(image_body)
    end

    it "serves the threads image" do
      get photo_media_path(photo_id: photo.id, style: 'threads')
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('image/jpeg')
    end

    it "serves the instagram story image" do
      get photo_media_path(photo_id: photo.id, style: 'instagram_story')
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('image/jpeg')
    end

    it "serves the cropped instagram story image" do
      get photo_media_path(photo_id: photo.id, style: 'instagram_story', crop: 'true')
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('image/jpeg')
    end

    it "sets cache headers" do
      get photo_media_path(photo_id: photo.id, style: 'instagram')
      expect(response.headers['Cache-Control']).to include('s-maxage')
      expect(response.headers['Cache-Control']).to include('public')
    end

    it "returns 404 for an invalid style" do
      get photo_media_path(photo_id: photo.id, style: 'invalid')
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for a non-existent photo" do
      get photo_media_path(photo_id: 0, style: 'instagram')
      expect(response).to have_http_status(:not_found)
    end
  end
end
