require 'rails_helper'

RSpec.describe "Admin::Equipment", type: :request do
  let(:user) { create(:user) }
  let!(:blog) { Blog.first || create(:blog) }
  let!(:camera) { create(:camera) }
  let!(:lens) { create(:lens) }
  let!(:film) { create(:film) }

  before do
    sign_in_as(user)
  end

  describe "GET /admin/equipment (index)" do
    it "renders successfully" do
      get admin_equipment_path
      expect(response).to have_http_status(:success)
    end

    it "displays cameras" do
      get admin_equipment_path
      expect(response.body).to include(camera.display_name)
    end

    it "displays lenses" do
      get admin_equipment_path
      expect(response.body).to include(lens.display_name)
    end

    it "displays films" do
      get admin_equipment_path
      expect(response.body).to include(film.display_name)
    end
  end
end
