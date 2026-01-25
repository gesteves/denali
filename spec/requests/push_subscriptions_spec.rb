require 'rails_helper'

RSpec.describe "PushSubscriptions", type: :request do
  let!(:blog) { Blog.first || create(:blog) }
  let(:valid_params) do
    {
      endpoint: 'https://fcm.googleapis.com/fcm/send/test-endpoint',
      keys: {
        p256dh: 'BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTpQtUbVlUls0VJXg7A8u-Ts1XbjhazAkj7I99e8QcYP7DkA',
        auth: 'tBHItJI5svbpez7KI4CCXg'
      }
    }
  end

  describe "POST /push-notifications/subscription (create)" do
    it "creates a new push subscription" do
      expect {
        post push_subscribe_path, params: valid_params, as: :json
      }.to change(PushSubscription, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it "returns success JSON" do
      post push_subscribe_path, params: valid_params, as: :json
      json = JSON.parse(response.body)
      expect(json['status']).to eq('success')
    end

    it "associates subscription with blog" do
      post push_subscribe_path, params: valid_params, as: :json
      expect(PushSubscription.last.blog).to eq(blog)
    end

    it "does not duplicate existing endpoint" do
      post push_subscribe_path, params: valid_params, as: :json
      expect {
        post push_subscribe_path, params: valid_params, as: :json
      }.not_to change(PushSubscription, :count)
    end

    it "returns error for invalid params" do
      # The controller requires keys parameter to be present
      invalid_params = {
        endpoint: '',
        keys: { p256dh: '', auth: '' }
      }
      post push_subscribe_path, params: invalid_params, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /push-notifications/subscription (destroy)" do
    let!(:push_subscription) do
      create(:push_subscription,
             blog: blog,
             endpoint: 'https://fcm.googleapis.com/fcm/send/existing-endpoint')
    end

    it "deletes an existing push subscription" do
      expect {
        delete push_notifications_subscription_path, params: { endpoint: push_subscription.endpoint }, as: :json
      }.to change(PushSubscription, :count).by(-1)
      expect(response).to have_http_status(:ok)
    end

    it "returns ok status" do
      delete push_notifications_subscription_path, params: { endpoint: push_subscription.endpoint }, as: :json
      json = JSON.parse(response.body)
      expect(json['status']).to eq('ok')
    end

    it "returns not found for non-existent endpoint" do
      delete push_notifications_subscription_path, params: { endpoint: 'non-existent' }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end
end
