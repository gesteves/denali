require 'rails_helper'

RSpec.describe "Admin::Crops", type: :request do
  let(:user) { create(:user) }
  let!(:blog) { Blog.first || create(:blog) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
  let(:photo) { entry.photos.first }

  before do
    sign_in_as(user)
    attach_image_to_photo(photo)
  end

  describe "POST /admin/entries/:entry_id/photos/:photo_id/crops/create_or_update" do
    # Crop values are normalized (0-1 range), not pixel values
    it "creates a new crop" do
      post create_or_update_admin_entry_photo_crops_path(entry, photo), params: {
        crop: {
          aspect_ratio: '1:1',
          x: 0.1,
          y: 0.1,
          width: 0.5,
          height: 0.5
        }
      }, as: :json
      expect(response).to have_http_status(:success)
      expect(photo.crops.where(aspect_ratio: '1:1').count).to eq(1)
    end

    it "updates existing crop with same aspect ratio" do
      crop = photo.crops.create!(aspect_ratio: '1:1', x: 0, y: 0, width: 0.5, height: 0.5)

      post create_or_update_admin_entry_photo_crops_path(entry, photo), params: {
        crop: {
          aspect_ratio: '1:1',
          x: 0.2,
          y: 0.2,
          width: 0.3,
          height: 0.3
        }
      }, as: :json
      expect(response).to have_http_status(:success)

      crop.reload
      expect(crop.x).to eq(0.2)
      expect(crop.y).to eq(0.2)
    end

    it "returns success JSON response" do
      post create_or_update_admin_entry_photo_crops_path(entry, photo), params: {
        crop: {
          aspect_ratio: '16:9',
          x: 0,
          y: 0,
          width: 1.0,
          height: 0.5625
        }
      }, as: :json
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['status']).to eq('success')
      expect(json['message']).to include('crop has been updated')
    end

    it "returns error JSON on failure" do
      allow_any_instance_of(Crop).to receive(:update).and_return(false)
      post create_or_update_admin_entry_photo_crops_path(entry, photo), params: {
        crop: {
          aspect_ratio: '1:1',
          x: 0.1,
          y: 0.1,
          width: 0.5,
          height: 0.5
        }
      }, as: :json
      json = JSON.parse(response.body)
      expect(json['status']).to eq('danger')
    end
  end
end
