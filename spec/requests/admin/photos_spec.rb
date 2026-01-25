require 'rails_helper'

RSpec.describe "Admin::Photos", type: :request do
  let(:user) { create(:user) }
  let!(:blog) { Blog.first || create(:blog) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
  let(:photo) { entry.photos.first }

  before do
    sign_in_as(user)
    attach_image_to_photo(photo)
  end

  describe "GET /admin/entries/:entry_id/photos/:id/download" do
    it "redirects to the image URL" do
      allow_any_instance_of(ActiveStorage::Blob).to receive(:url).and_return('http://example.com/image.jpg')
      get download_admin_entry_photo_path(entry, photo)
      expect(response).to have_http_status(:found)
      expect(response.location).to eq('http://example.com/image.jpg')
    end
  end

  describe "POST /admin/entries/:entry_id/photos/:id/focal_point" do
    it "updates the focal point" do
      post focal_point_admin_entry_photo_path(entry, photo), params: {
        photo: { focal_x: 0.3, focal_y: 0.7 }
      }, as: :json
      expect(response).to have_http_status(:success)
      photo.reload
      expect(photo.focal_x).to eq(0.3)
      expect(photo.focal_y).to eq(0.7)
    end

    it "returns JSON success response" do
      post focal_point_admin_entry_photo_path(entry, photo), params: {
        photo: { focal_x: 0.5, focal_y: 0.5 }
      }, as: :json
      json = JSON.parse(response.body)
      expect(json['status']).to eq('success')
      expect(json['message']).to include('focal point')
    end
  end

  describe "POST /admin/photos/:id/generate_alt_text" do
    before do
      allow(AltTextWorker).to receive(:perform_inline)
      photo.update!(auto_generated_alt_text: 'Generated description')
    end

    it "calls AltTextWorker" do
      expect(AltTextWorker).to receive(:perform_inline).with(photo.id.to_s)
      post generate_alt_text_admin_photo_path(photo), as: :json
    end

    it "returns the generated alt text" do
      post generate_alt_text_admin_photo_path(photo), as: :json
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['status']).to eq('success')
      expect(json['auto_generated_alt_text']).to eq('Generated description')
    end
  end

  describe "POST /admin/photos/:id/approve_alt_text" do
    before do
      photo.update!(auto_generated_alt_text: 'Auto generated text', alt_text_needs_review: true)
    end

    it "approves the alt text" do
      post approve_alt_text_admin_photo_path(photo), params: { text: 'Approved text' }, as: :json
      expect(response).to have_http_status(:success)
      photo.reload
      expect(photo.alt_text).to eq('Approved text')
    end

    it "returns the approved alt text" do
      post approve_alt_text_admin_photo_path(photo), params: { text: 'Approved text' }, as: :json
      json = JSON.parse(response.body)
      expect(json['status']).to eq('success')
      expect(json['alt_text']).to eq('Approved text')
    end
  end

  describe "POST /admin/photos/:id/dismiss_alt_text" do
    before do
      photo.update!(alt_text_needs_review: true)
    end

    it "dismisses the alt text review" do
      post dismiss_alt_text_admin_photo_path(photo), as: :json
      expect(response).to have_http_status(:success)
      photo.reload
      expect(photo.alt_text_needs_review).to be false
    end

    it "returns success response" do
      post dismiss_alt_text_admin_photo_path(photo), as: :json
      json = JSON.parse(response.body)
      expect(json['status']).to eq('success')
    end
  end
end
