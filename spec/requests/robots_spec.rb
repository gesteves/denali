require 'rails_helper'

RSpec.describe "Robots", type: :request do
  let!(:blog) { Blog.first || create(:blog) }

  describe "GET /robots.txt" do
    before do
      allow(Rails.cache).to receive(:fetch).and_call_original
      allow(Rails.cache).to receive(:fetch).with("known-agents", anything).and_return("User-agent: GPTBot\nDisallow: /")
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

    it "points at the sitemap" do
      get '/robots.txt'
      expect(response.body).to include("Sitemap:")
    end

    it "starts with the content signals preamble" do
      get '/robots.txt'
      expect(response.body).to start_with("# As a condition of accessing this website")
    end

    it "declares content signals for all user agents" do
      get '/robots.txt'
      expect(response.body).to include("User-agent: *\nContent-Signal: search=yes,ai-train=no,use=reference\nDisallow: /random")
    end

    it "includes the known agents rules" do
      get '/robots.txt'
      expect(response.body).to include("User-agent: GPTBot\nDisallow: /")
    end
  end
end
