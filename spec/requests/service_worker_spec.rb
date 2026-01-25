require 'rails_helper'

RSpec.describe "ServiceWorker", type: :request do
  let!(:blog) { Blog.first || create(:blog) }

  describe "GET /service-worker.js" do
    it "renders successfully" do
      get service_worker_path(format: :js)
      expect(response).to have_http_status(:success)
    end

    it "returns JavaScript content type" do
      get service_worker_path(format: :js)
      expect(response.content_type).to include("text/javascript")
    end
  end
end
