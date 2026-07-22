require 'rails_helper'

RSpec.describe "Robots", type: :request do
  let!(:blog) { Blog.first || create(:blog) }

  describe "GET /robots.txt" do
    it "renders successfully" do
      get '/robots.txt'
      expect(response).to have_http_status(:success)
    end

    it "returns text content type" do
      get '/robots.txt'
      expect(response.content_type).to include("text/plain")
    end

    it "includes user-agent directives" do
      get '/robots.txt'
      expect(response.body).to include("User-agent")
    end

    it "points at the sitemap" do
      get '/robots.txt'
      expect(response.body).to include("Sitemap:")
    end
  end
end
