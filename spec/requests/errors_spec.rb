require 'rails_helper'

RSpec.describe "Errors", type: :request do
  let!(:blog) { Blog.first || create(:blog) }

  describe "GET /404" do
    it "renders with 404 status" do
      get "/404"
      expect(response).to have_http_status(:not_found)
    end

    it "renders HTML format" do
      get "/404"
      expect(response.content_type).to include("text/html")
    end

    it "renders JSON format" do
      get "/404.json"
      expect(response).to have_http_status(:not_found)
      expect(response.content_type).to include("application/json")
    end
  end

  describe "GET /422" do
    it "renders with 422 status" do
      get "/422"
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /500" do
    it "renders with 500 status" do
      get "/500"
      expect(response).to have_http_status(:internal_server_error)
    end

    it "renders JSON format" do
      get "/500.json"
      expect(response).to have_http_status(:internal_server_error)
      expect(response.content_type).to include("application/json")
    end
  end
end
