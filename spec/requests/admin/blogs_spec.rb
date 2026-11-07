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

    it "offers every Bluesky reply audience" do
      get edit_admin_blog_path(blog)

      Bluesky::REPLY_AUDIENCES.each_key do |audience|
        expect(response.body).to include(%(value="#{audience}"))
      end
    end

    it "offers the Bluesky quote post setting" do
      get edit_admin_blog_path(blog)
      expect(response.body).to include('name="blog[bluesky_allow_quotes]"')
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

    it "updates the Bluesky interaction settings" do
      patch admin_blog_path(blog), params: {
        blog: { bluesky_reply_audience: 'followers', bluesky_allow_quotes: 'false' }
      }

      blog.reload
      expect(blog.bluesky_reply_audience).to eq('followers')
      expect(blog.bluesky_allow_quotes).to be false
    end

    it "refuses a Bluesky reply audience that doesn't exist" do
      patch admin_blog_path(blog), params: { blog: { bluesky_reply_audience: 'bots' } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(blog.reload.bluesky_reply_audience).to eq('everyone')
    end

    it "sets flash message on success" do
      patch admin_blog_path(blog), params: { blog: { name: 'New Name' } }
      expect(flash[:success]).to be_present
    end

    it "renders edit on invalid params" do
      allow(Blog).to receive(:first).and_return(blog)
      allow(blog).to receive(:update).and_return(false)
      patch admin_blog_path(blog), params: { blog: { name: '' } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "purges cached pages, which render the blog's settings" do
      expect(CachePurgeJob).to receive(:enqueue).with(CacheTags::BLOG, CacheTags::ENTRIES)

      patch admin_blog_path(blog), params: { blog: { name: 'New Name' } }
    end

    it "records the settings change, so pages already in a browser stop revalidating to 304" do
      expect {
        patch admin_blog_path(blog), params: { blog: { name: 'New Name' } }
      }.to change { blog.reload.settings_updated_at }
    end

    it "does not purge when the update fails" do
      allow(Blog).to receive(:first).and_return(blog)
      allow(blog).to receive(:update).and_return(false)

      expect(CachePurgeJob).not_to receive(:enqueue)

      patch admin_blog_path(blog), params: { blog: { name: '' } }
    end
  end
end
