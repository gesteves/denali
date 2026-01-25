require 'rails_helper'

RSpec.describe "Legacy", type: :request do
  let!(:blog) { Blog.first || create(:blog) }

  describe "GET /archive (legacy home)" do
    it "redirects to root with 301" do
      get '/archive'
      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to(root_url)
    end
  end

  describe "GET /index.html (legacy home)" do
    it "redirects to root with 301" do
      get '/index.html'
      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to(root_url)
    end
  end

  describe "GET /rss (legacy feed)" do
    it "redirects to feed with 301" do
      get '/rss'
      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to(feed_url)
    end
  end
end
