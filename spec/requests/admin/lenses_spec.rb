require 'rails_helper'

RSpec.describe "Admin::Lenses", type: :request do
  let(:user) { create(:user) }
  let!(:blog) { Blog.first || create(:blog) }
  let!(:lens) { create(:lens) }

  before do
    sign_in_as(user)
  end

  describe "GET /admin/lenses/:id/edit" do
    it "renders successfully" do
      get edit_admin_lens_path(lens)
      expect(response).to have_http_status(:success)
    end

    it "displays lens information" do
      get edit_admin_lens_path(lens)
      expect(response.body).to include("Editing lens")
    end
  end

  describe "PATCH /admin/lenses/:id (update)" do
    it "updates the lens" do
      patch admin_lens_path(lens), params: {
        lens: { display_name: 'Updated Lens Name' }
      }
      expect(response).to redirect_to(admin_equipment_path)
      lens.reload
      expect(lens.display_name).to eq('Updated Lens Name')
    end

    it "sets flash message on success" do
      patch admin_lens_path(lens), params: {
        lens: { display_name: 'New Name' }
      }
      expect(flash[:success]).to be_present
    end

    it "renders edit on invalid params" do
      allow_any_instance_of(Lens).to receive(:update).and_return(false)
      patch admin_lens_path(lens), params: {
        lens: { display_name: '' }
      }
      expect(response).to have_http_status(:success)
    end
  end
end
