require 'rails_helper'

RSpec.describe "Manifest", type: :request do
  let!(:blog) { Blog.first || create(:blog) }

  describe "GET /manifest.json" do
    it "renders successfully" do
      get manifest_path(format: :json)
      expect(response).to have_http_status(:success)
    end

    it "returns JSON content type" do
      get manifest_path(format: :json)
      expect(response.content_type).to include("application/json")
    end

    it "contains icons array" do
      get manifest_path(format: :json)
      json = JSON.parse(response.body)
      expect(json).to have_key("icons")
      expect(json["icons"]).to be_an(Array)
    end
  end
end
