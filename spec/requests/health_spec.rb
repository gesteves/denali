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

    it "checks the database" do
      expect(ActiveRecord::Base).to receive(:with_connection).and_call_original
      get health_check_path
      expect(response).to have_http_status(:ok)
    end

    it "doesn't need a blog" do
      Blog.destroy_all
      get health_check_path
      expect(response).to have_http_status(:ok)
    end

    context "when the database is unreachable" do
      before do
        allow(ActiveRecord::Base).to receive(:with_connection).and_raise(ActiveRecord::ConnectionNotEstablished)
        allow(Process).to receive(:kill)
      end

      it "returns 503 and asks Puma to shut down so the machine restarts" do
        get health_check_path

        expect(response).to have_http_status(:service_unavailable)
        expect(Process).to have_received(:kill).with('TERM', Process.pid)
      end
    end
  end
end
