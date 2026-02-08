require 'rails_helper'

RSpec.describe WebhookJob, type: :worker do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
  let(:webhook) { create(:webhook, :ifttt, blog: blog) }

  before do
    entry.photos.each { |p| attach_image_to_photo(p) }
  end

  describe '#perform' do
    context 'in production environment' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      end

      it 'sends webhook with payload for IFTTT webhook' do
        stub = stub_request(:post, webhook.url)
          .with(
            body: webhook.payload(entry),
            headers: { 'Content-Type' => 'application/json' }
          )
          .to_return(status: 200, body: '', headers: {})

        described_class.new.perform(webhook.id, entry.id)

        expect(stub).to have_been_requested
      end

      it 'sends webhook without payload for generic webhook' do
        generic_webhook = create(:webhook, blog: blog)
        stub = stub_request(:post, generic_webhook.url)
          .to_return(status: 200, body: '', headers: {})

        described_class.new.perform(generic_webhook.id, entry.id)

        expect(stub).to have_been_requested
      end

      it 'raises error when response is 4xx or 5xx' do
        stub_request(:post, webhook.url)
          .to_return(status: 500, body: 'Internal Server Error', headers: {})

        expect {
          described_class.new.perform(webhook.id, entry.id)
        }.to raise_error(RuntimeError, /Failed to send webhook/)
      end

      it 'raises UnprocessedPhotoError when photo entry lacks dimensions' do
        allow_any_instance_of(Entry).to receive(:photos_have_dimensions?).and_return(false)

        expect {
          described_class.new.perform(webhook.id, entry.id)
        }.to raise_error(UnprocessedPhotoError)
      end
    end

    context 'in non-production environment' do
      it 'returns early without making HTTP request' do
        expect(HTTParty).not_to receive(:post)
        described_class.new.perform(webhook.id, entry.id)
      end
    end
  end

  describe 'Sidekiq configuration' do
    it 'uses the high queue' do
      expect(described_class.sidekiq_options['queue']).to eq('high')
    end
  end
end
