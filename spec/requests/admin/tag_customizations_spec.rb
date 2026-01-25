require 'rails_helper'

RSpec.describe "Admin::TagCustomizations", type: :request do
  let(:user) { create(:user) }
  let!(:blog) { Blog.first || create(:blog) }
  let!(:tag_customization) { create(:tag_customization, blog: blog) }

  before do
    sign_in_as(user)
  end

  describe "GET /admin/tag_customizations (index)" do
    it "renders successfully" do
      get admin_tag_customizations_path
      expect(response).to have_http_status(:success)
    end

    it "displays page title" do
      get admin_tag_customizations_path
      expect(response.body).to include("Tags")
    end
  end

  describe "GET /admin/tag_customizations/new" do
    it "renders successfully" do
      get new_admin_tag_customization_path
      expect(response).to have_http_status(:success)
    end

    it "displays page title" do
      get new_admin_tag_customization_path
      expect(response.body).to include("Set up a tag")
    end
  end

  describe "POST /admin/tag_customizations (create)" do
    it "creates a new tag customization" do
      expect {
        post admin_tag_customizations_path, params: {
          tag_customization: {
            tag_list: 'nature, landscape',
            bluesky_hashtags: '#nature #landscape',
            mastodon_hashtags: '#nature #landscape'
          }
        }
      }.to change(TagCustomization, :count).by(1)
      expect(response).to redirect_to(admin_tag_customizations_path)
      expect(flash[:success]).to be_present
    end

    it "associates with blog" do
      post admin_tag_customizations_path, params: {
        tag_customization: {
          tag_list: 'test',
          bluesky_hashtags: '#test'
        }
      }
      expect(TagCustomization.last.blog).to eq(blog)
    end

    it "renders new on invalid params" do
      allow_any_instance_of(TagCustomization).to receive(:save).and_return(false)
      post admin_tag_customizations_path, params: {
        tag_customization: { tag_list: '' }
      }
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /admin/tag_customizations/:id/edit" do
    it "renders successfully" do
      get edit_admin_tag_customization_path(tag_customization)
      expect(response).to have_http_status(:success)
    end

    it "displays page title" do
      get edit_admin_tag_customization_path(tag_customization)
      expect(response.body).to include("Edit tag settings")
    end
  end

  describe "PATCH /admin/tag_customizations/:id (update)" do
    it "updates the tag customization" do
      patch admin_tag_customization_path(tag_customization), params: {
        tag_customization: { bluesky_hashtags: '#updated #hashtags' }
      }
      expect(response).to redirect_to(admin_tag_customizations_path)
      tag_customization.reload
      # Hashtags may be reordered during normalization
      saved_hashtags = tag_customization.bluesky_hashtags.split(/\s+/).sort
      expect(saved_hashtags).to match_array(['#hashtags', '#updated'])
    end

    it "sets flash message on success" do
      patch admin_tag_customization_path(tag_customization), params: {
        tag_customization: { bluesky_hashtags: '#new' }
      }
      expect(flash[:success]).to be_present
    end

    it "renders edit on invalid params" do
      allow_any_instance_of(TagCustomization).to receive(:update).and_return(false)
      patch admin_tag_customization_path(tag_customization), params: {
        tag_customization: { tag_list: '' }
      }
      expect(response).to have_http_status(:success)
    end
  end

  describe "DELETE /admin/tag_customizations/:id (destroy)" do
    it "deletes the tag customization" do
      expect {
        delete admin_tag_customization_path(tag_customization)
      }.to change(TagCustomization, :count).by(-1)
      expect(response).to redirect_to(admin_tag_customizations_path)
    end
  end
end
