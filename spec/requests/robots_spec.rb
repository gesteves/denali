require 'rails_helper'

RSpec.describe "Robots", type: :request do
  let!(:blog) { Blog.first || create(:blog) }

  describe "GET /robots.txt" do
    before do
      allow(Rails.cache).to receive(:fetch).and_call_original
      allow(Rails.cache).to receive(:fetch).with("known-agents", anything).and_return("User-agent: *\nDisallow: /admin/")
    end

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
  end
end
