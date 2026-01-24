require 'rails_helper'

RSpec.describe Webhook, type: :model do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }

  describe 'associations' do
    it { should belong_to(:blog) }
  end

  describe 'validations' do
    it { should validate_presence_of(:url) }
  end

  describe 'factory' do
    it 'creates a valid webhook' do
      webhook = create(:webhook)
      expect(webhook).to be_valid
    end
  end

  describe '#payload' do
    let(:entry) { create(:entry, :published, blog: blog, user: user) }

    context 'with IFTTT webhook' do
      let(:webhook) { create(:webhook, :ifttt, blog: blog) }

      it 'returns IFTTT formatted payload' do
        payload = JSON.parse(webhook.payload(entry))
        expect(payload['value1']).to eq(entry.plain_title)
        expect(payload['value2']).to eq(entry.permalink_url)
      end
    end

    context 'with Slack webhook' do
      let(:webhook) { create(:webhook, :slack, blog: blog) }

      it 'returns Slack formatted payload' do
        payload = JSON.parse(webhook.payload(entry))
        expect(payload['text']).to include(entry.permalink_url)
        expect(payload['unfurl_links']).to be true
      end
    end

    context 'with Discord webhook' do
      let(:webhook) { create(:webhook, :discord, blog: blog) }

      it 'returns Discord formatted payload' do
        payload = JSON.parse(webhook.payload(entry))
        expect(payload['content']).to include(entry.permalink_url)
      end
    end

    context 'with unknown webhook type' do
      let(:webhook) { create(:webhook, blog: blog) }

      it 'returns nil' do
        expect(webhook.payload(entry)).to be_nil
      end
    end
  end

  describe '.deliver_all' do
    it 'enqueues WebhookWorker for each webhook' do
      create_list(:webhook, 3, blog: blog)
      entry = create(:entry, blog: blog, user: user)

      expect {
        Webhook.deliver_all(entry)
      }.to change(WebhookWorker.jobs, :size).by(3)
    end
  end
end
