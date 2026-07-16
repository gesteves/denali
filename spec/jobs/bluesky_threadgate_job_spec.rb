require 'rails_helper'

RSpec.describe BlueskyThreadgateJob, type: :worker do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
  let(:post_uri) { 'at://did:plc:abcd1234/app.bsky.feed.post/123' }

  before do
    create_list(:webhook, 2, blog: blog)
  end

  describe '#perform' do
    context 'in production environment with connected account' do
      let(:bluesky_instance) { instance_double(Bluesky) }
      let!(:bluesky_account) do
        create(:social_account,
          user: user,
          provider: 'bluesky',
          handle: 'test.bsky.social',
          access_token: 'app-password',
          server_url: 'https://bsky.social'
        )
      end

      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        allow(Bluesky).to receive(:from_social_account).with(bluesky_account).and_return(bluesky_instance)
        allow(bluesky_instance).to receive(:create_threadgate)
      end

      it 'creates a threadgate for the post' do
        expect(bluesky_instance).to receive(:create_threadgate).with(post_uri)
        described_class.new.perform(entry.id, post_uri)
      end

      it 'lets API errors bubble up so Sidekiq retries' do
        allow(bluesky_instance).to receive(:create_threadgate).and_raise('Failed to create app.bsky.feed.threadgate record')

        expect { described_class.new.perform(entry.id, post_uri) }.to raise_error(/Failed to create/)
      end

      it 'returns early when the post uri is blank' do
        expect(Bluesky).not_to receive(:from_social_account)
        described_class.new.perform(entry.id, nil)
      end
    end

    context 'in non-production environment' do
      it 'returns early without calling Bluesky API' do
        expect(Bluesky).not_to receive(:from_social_account)
        described_class.new.perform(entry.id, post_uri)
      end
    end

    context 'without connected account' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      end

      it 'returns early without calling Bluesky API' do
        expect(Bluesky).not_to receive(:from_social_account)
        described_class.new.perform(entry.id, post_uri)
      end
    end

    context 'when entry does not exist' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      end

      it 'raises ActiveRecord::RecordNotFound' do
        expect(Bluesky).not_to receive(:from_social_account)
        expect { described_class.new.perform(999999, post_uri) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'Sidekiq configuration' do
    it 'uses the high queue' do
      expect(described_class.sidekiq_options['queue']).to eq('high')
    end
  end
end
