require 'rails_helper'

RSpec.describe "Admin::Territories", type: :request do
  let(:user) { create(:user) }
  let!(:blog) { Blog.first || create(:blog) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
  let(:photo) { entry.photos.first }
  let!(:territory) { create(:territory) }

  before do
    sign_in_as(user)
    attach_image_to_photo(photo)
    photo.territories << territory
  end

  describe "GET /admin/territories (index)" do
    it "renders successfully" do
      get admin_territories_path
      expect(response).to have_http_status(:success)
    end

    it "displays page title" do
      get admin_territories_path
      expect(response.body).to include("Territories")
    end

    it "displays territories with entry counts" do
      get admin_territories_path
      expect(response.body).to include(territory.name)
    end
  end
end
