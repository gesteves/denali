require 'rails_helper'

RSpec.describe "Admin::Parks", type: :request do
  let(:user) { create(:user) }
  let!(:blog) { Blog.first || create(:blog) }
  let!(:park) { create(:park) }

  before do
    sign_in_as(user)
  end

  describe "GET /admin/parks/:id/edit" do
    it "renders successfully" do
      get edit_admin_park_path(park)
      expect(response).to have_http_status(:success)
    end

    it "displays park information" do
      get edit_admin_park_path(park)
      expect(response.body).to include("Editing national park")
    end
  end

  describe "PATCH /admin/parks/:id (update)" do
    it "updates the park" do
      patch admin_park_path(park), params: {
        park: { display_name: 'Updated Park Name' }
      }
      expect(response).to redirect_to(admin_locations_path)
      park.reload
      expect(park.display_name).to eq('Updated Park Name')
    end

    it "updates instagram location id" do
      patch admin_park_path(park), params: {
        park: { instagram_location_id: '123456789' }
      }
      park.reload
      expect(park.instagram_location_id).to eq('123456789')
    end

    it "sets flash message on success" do
      patch admin_park_path(park), params: {
        park: { display_name: 'New Name' }
      }
      expect(flash[:success]).to be_present
    end

    it "renders edit on invalid params" do
      allow(Park).to receive(:find).with(park.id.to_s).and_return(park)
      allow(park).to receive(:update).and_return(false)
      patch admin_park_path(park), params: {
        park: { display_name: '' }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
