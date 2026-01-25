require 'rails_helper'

RSpec.describe "Admin::Cameras", type: :request do
  let(:user) { create(:user) }
  let!(:blog) { Blog.first || create(:blog) }
  let!(:camera) { create(:camera) }

  before do
    sign_in_as(user)
  end

  describe "GET /admin/cameras/:id/edit" do
    it "renders successfully" do
      get edit_admin_camera_path(camera)
      expect(response).to have_http_status(:success)
    end

    it "displays camera information" do
      get edit_admin_camera_path(camera)
      expect(response.body).to include("Editing camera")
    end
  end

  describe "PATCH /admin/cameras/:id (update)" do
    it "updates the camera" do
      patch admin_camera_path(camera), params: {
        camera: { display_name: 'Updated Camera Name' }
      }
      expect(response).to redirect_to(admin_equipment_path)
      camera.reload
      expect(camera.display_name).to eq('Updated Camera Name')
    end

    it "sets flash message on success" do
      patch admin_camera_path(camera), params: {
        camera: { display_name: 'New Name' }
      }
      expect(flash[:success]).to be_present
    end

    it "renders edit on invalid params" do
      allow_any_instance_of(Camera).to receive(:update).and_return(false)
      patch admin_camera_path(camera), params: {
        camera: { display_name: '' }
      }
      expect(response).to have_http_status(:success)
    end
  end
end
