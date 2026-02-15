require 'rails_helper'

RSpec.describe "Legacy", type: :request do
  let!(:blog) { Blog.first || create(:blog) }

  describe "GET /archive (legacy home)" do
    it "redirects to root with 301" do
      get '/archive'
      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to('/')
    end
  end

  describe "GET /index.html (legacy home)" do
    it "redirects to root with 301" do
      get '/index.html'
      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to('/')
    end
  end

  describe "GET /rss (legacy feed)" do
    it "redirects to feed with 301" do
      get '/rss'
      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to('/feed')
    end
  end

  describe "GET /:year/:month/:day/:id/:slug (legacy date-based URL)" do
    let(:user) { create(:user) }
    let(:entry) { create(:entry, :published, blog: blog, user: user) }

    it "redirects to canonical URL with 301" do
      get "/#{entry.published_at.strftime('%Y/%-m/%-d')}/#{entry.id}/#{entry.slug}"
      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to("/#{entry.id}/#{entry.slug}")
    end

    it "redirects AMP URL to canonical URL with 301" do
      get "/amp/#{entry.published_at.strftime('%Y/%-m/%-d')}/#{entry.id}/#{entry.slug}"
      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to("/#{entry.id}/#{entry.slug}")
    end
  end
end
