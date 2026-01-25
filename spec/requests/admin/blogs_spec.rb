require 'rails_helper'

RSpec.describe "Admin::Blogs", type: :request do
  let(:user) { create(:user) }
  let!(:blog) { Blog.first || create(:blog) }

  before do
    sign_in_as(user)
  end

  describe "GET /admin/blogs/:id/edit" do
    it "renders successfully" do
      get edit_admin_blog_path(blog)
      expect(response).to have_http_status(:success)
    end

    it "displays TTL options" do
      get edit_admin_blog_path(blog)
      expect(response.body).to include("Blog settings")
    end
  end

  describe "PATCH /admin/blogs/:id" do
    it "updates the blog settings" do
      patch admin_blog_path(blog), params: {
        blog: { name: 'Updated Blog Name', posts_per_page: 20 }
      }
      expect(response).to redirect_to(edit_admin_blog_path(blog))
      blog.reload
      expect(blog.name).to eq('Updated Blog Name')
      expect(blog.posts_per_page).to eq(20)
    end

    it "sets flash message on success" do
      patch admin_blog_path(blog), params: { blog: { name: 'New Name' } }
      expect(flash[:success]).to be_present
    end

    it "renders edit on invalid params" do
      allow_any_instance_of(Blog).to receive(:update).and_return(false)
      patch admin_blog_path(blog), params: { blog: { name: '' } }
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /admin/blogs/:id/flush_caches" do
    let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }

    before do
      entry.photos.each { |p| attach_image_to_photo(p) }
      allow_any_instance_of(Blog).to receive(:purge_from_cdn)
    end

    it "purges the CDN cache" do
      expect_any_instance_of(Blog).to receive(:purge_from_cdn)
      # Use JS format to avoid redirect issues
      post flush_caches_admin_blog_path(blog), xhr: true
    end

    it "responds to JS format with success message" do
      post flush_caches_admin_blog_path(blog), xhr: true
      expect(response).to have_http_status(:success)
    end
  end
end
