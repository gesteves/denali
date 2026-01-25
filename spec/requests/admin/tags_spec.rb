require 'rails_helper'

RSpec.describe "Admin::Tags", type: :request do
  let(:user) { create(:user) }
  let!(:blog) { Blog.first || create(:blog) }
  let!(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
  let!(:tag) do
    entry.photos.each { |p| attach_image_to_photo(p) }
    entry.tag_list.add('TestTag')
    entry.save!
    ActsAsTaggableOn::Tag.find_by!(name: 'TestTag')
  end

  before do
    sign_in_as(user)
  end

  describe "GET /admin/tags (index)" do
    it "renders successfully" do
      tag # ensure tag is created
      get admin_tags_path
      expect(response).to have_http_status(:success)
    end

    it "displays tags" do
      tag # ensure tag is created
      get admin_tags_path
      expect(response.body).to include('TestTag')
    end

    it "paginates results" do
      tag # ensure tag is created
      get admin_tags_path(page: 1)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /admin/tags/:id (show)" do
    it "redirects to tagged entries" do
      get admin_tag_path(id: tag.id)
      expect(response).to redirect_to(admin_tagged_entries_path(tag.slug))
    end
  end

  describe "PATCH /admin/tags/:id (update)" do
    it "updates the tag name" do
      patch admin_tag_path(id: tag.id), params: { name: 'UpdatedTag' }, as: :json
      expect(response).to have_http_status(:success)
      tag.reload
      expect(tag.name).to eq('UpdatedTag')
    end

    it "touches associated entries" do
      tag # ensure tag is created
      entry.touch
      original_updated_at = entry.reload.updated_at
      travel_to 1.second.from_now do
        patch admin_tag_path(id: tag.id), params: { name: 'NewName' }, as: :json
        entry.reload
        expect(entry.updated_at).to be > original_updated_at
      end
    end

    it "returns error on invalid update" do
      allow(ActsAsTaggableOn::Tag).to receive(:find).with(tag.id.to_s).and_return(tag)
      allow(tag).to receive(:update).and_return(false)
      patch admin_tag_path(id: tag.id), params: { name: '' }, as: :json
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "DELETE /admin/tags/:id (destroy)" do
    it "deletes the tag" do
      tag_to_delete = tag
      expect {
        delete admin_tag_path(id: tag_to_delete.id)
      }.to change(ActsAsTaggableOn::Tag, :count).by(-1)
      expect(response).to redirect_to(admin_tags_path)
    end

    it "returns JSON response" do
      delete admin_tag_path(id: tag.id), as: :json
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['status']).to eq('danger')
    end

    it "touches associated entries" do
      tag # ensure tag is created
      entry.touch
      original_updated_at = entry.reload.updated_at
      travel_to 1.second.from_now do
        delete admin_tag_path(id: tag.id)
        entry.reload
        expect(entry.updated_at).to be > original_updated_at
      end
    end
  end

  describe "POST /admin/tags/:id/add" do
    it "adds new tags to all entries with the original tag" do
      post add_admin_tag_path(id: tag.id), params: { tags: 'NewTag' }
      entry.reload
      expect(entry.tag_list).to include('NewTag')
    end

    it "redirects to tags index" do
      post add_admin_tag_path(id: tag.id), params: { tags: 'AnotherTag' }
      expect(response).to redirect_to(admin_tags_path)
    end

    it "returns JSON response" do
      post add_admin_tag_path(id: tag.id), params: { tags: 'JsonTag' }, as: :json
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['status']).to eq('success')
    end
  end
end
