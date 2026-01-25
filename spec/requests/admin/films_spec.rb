require 'rails_helper'

RSpec.describe "Admin::Films", type: :request do
  let(:user) { create(:user) }
  let!(:blog) { Blog.first || create(:blog) }
  let!(:film) { create(:film) }

  before do
    sign_in_as(user)
  end

  describe "GET /admin/films/:id/edit" do
    it "renders successfully" do
      get edit_admin_film_path(film)
      expect(response).to have_http_status(:success)
    end

    it "displays film information" do
      get edit_admin_film_path(film)
      expect(response.body).to include("Editing film")
    end
  end

  describe "PATCH /admin/films/:id (update)" do
    it "updates the film" do
      patch admin_film_path(film), params: {
        film: { display_name: 'Updated Film Name' }
      }
      expect(response).to redirect_to(admin_equipment_path)
      film.reload
      expect(film.display_name).to eq('Updated Film Name')
    end

    it "sets flash message on success" do
      patch admin_film_path(film), params: {
        film: { display_name: 'New Name' }
      }
      expect(flash[:success]).to be_present
    end

    it "renders edit on invalid params" do
      allow(Film).to receive(:find).with(film.id.to_s).and_return(film)
      allow(film).to receive(:update).and_return(false)
      patch admin_film_path(film), params: {
        film: { display_name: '' }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
