require 'rails_helper'

RSpec.describe "Admin::Webhooks", type: :request do
  let(:user) { create(:user) }
  let!(:blog) { Blog.first || create(:blog) }
  let!(:webhook) { create(:webhook, blog: blog) }

  before do
    sign_in_as(user)
  end

  describe "GET /admin/webhooks (index)" do
    it "renders successfully" do
      get admin_webhooks_path
      expect(response).to have_http_status(:success)
    end

    it "displays webhooks" do
      get admin_webhooks_path
      expect(response.body).to include(webhook.url)
    end

    it "paginates results" do
      get admin_webhooks_path(page: 1)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /admin/webhooks/new" do
    it "renders successfully" do
      get new_admin_webhook_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /admin/webhooks (create)" do
    it "creates a new webhook" do
      expect {
        post admin_webhooks_path, params: {
          webhook: { url: 'https://example.com/webhook' }
        }
      }.to change(Webhook, :count).by(1)
      expect(response).to redirect_to(admin_webhooks_path)
      expect(flash[:success]).to be_present
    end

    it "associates webhook with blog" do
      post admin_webhooks_path, params: {
        webhook: { url: 'https://example.com/webhook' }
      }
      expect(Webhook.last.blog).to eq(blog)
    end

    it "renders new on invalid params" do
      post admin_webhooks_path, params: {
        webhook: { url: '' }
      }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(flash[:warning]).to be_present
    end
  end

  describe "GET /admin/webhooks/:id/edit" do
    it "renders successfully" do
      get edit_admin_webhook_path(webhook)
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /admin/webhooks/:id (update)" do
    it "updates the webhook" do
      patch admin_webhook_path(webhook), params: {
        webhook: { url: 'https://updated.example.com/webhook' }
      }
      expect(response).to redirect_to(admin_webhooks_path)
      webhook.reload
      expect(webhook.url).to eq('https://updated.example.com/webhook')
    end

    it "sets flash message on success" do
      patch admin_webhook_path(webhook), params: {
        webhook: { url: 'https://updated.example.com/webhook' }
      }
      expect(flash[:success]).to be_present
    end

    it "renders edit on invalid params" do
      allow(Webhook).to receive(:find).with(webhook.id.to_s).and_return(webhook)
      allow(webhook).to receive(:update).and_return(false)
      patch admin_webhook_path(webhook), params: {
        webhook: { url: '' }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /admin/webhooks/:id (destroy)" do
    it "deletes the webhook" do
      expect {
        delete admin_webhook_path(webhook)
      }.to change(Webhook, :count).by(-1)
      expect(response).to redirect_to(admin_webhooks_path)
    end
  end
end
