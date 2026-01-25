require 'rails_helper'

RSpec.describe "Admin::Locations", type: :request do
  let(:user) { create(:user) }
  let!(:blog) { Blog.first || create(:blog) }
  let!(:park) { create(:park) }

  before do
    sign_in_as(user)
  end

  describe "GET /admin/locations (index)" do
    it "renders successfully" do
      get admin_locations_path
      expect(response).to have_http_status(:success)
    end

    it "displays page title" do
      get admin_locations_path
      expect(response.body).to include("Locations")
    end

    it "displays parks" do
      get admin_locations_path
      # The view displays display_name, not full_name
      expect(response.body).to include(park.display_name)
    end
  end
end
