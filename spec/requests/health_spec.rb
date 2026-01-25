require 'rails_helper'

RSpec.describe "Health", type: :request do
  let!(:blog) { Blog.first || create(:blog) }

  describe "GET /healthcheck" do
    it "returns OK status" do
      get health_check_path
      expect(response).to have_http_status(:ok)
    end

    it "returns OK text" do
      get health_check_path
      expect(response.body).to eq("OK")
    end

    it "returns plain text content type" do
      get health_check_path
      expect(response.content_type).to include("text/plain")
    end
  end
end
