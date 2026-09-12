require 'rails_helper'

RSpec.describe BlueskyJob, type: :worker do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }

  before do
    entry.photos.each { |p| attach_image_to_photo(p) }
    create_list(:webhook, 2, blog: blog)
  end

  describe '#perform' do
    let(:text) { 'Test caption for Bluesky' }
    let(:post_uri) { 'at://did:plc:abcd1234/app.bsky.feed.post/123' }

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
        allow(bluesky_instance).to receive(:skeet).and_return({ 'uri' => post_uri })
      end

      it 'enqueues a threadgate job to restrict replies on the new post' do
        expect(BlueskyThreadgateJob).to receive(:perform_async).with(entry.id, post_uri)
        described_class.new.perform(entry.id, text)
      end

      it 'enqueues a threadgate job for quote posts, which are root posts too' do
        expect(BlueskyThreadgateJob).to receive(:perform_async).with(entry.id, post_uri)
        described_class.new.perform(entry.id, text, nil, 'quote_uri')
      end

      it 'does not enqueue a threadgate job for replies, which inherit the root post gate' do
        expect(BlueskyThreadgateJob).not_to receive(:perform_async)
        described_class.new.perform(entry.id, text, 'reply_uri')
      end

      it 'does not enqueue a threadgate job when the post uri is missing' do
        allow(bluesky_instance).to receive(:skeet).and_return({})

        expect(BlueskyThreadgateJob).not_to receive(:perform_async)
        described_class.new.perform(entry.id, text)
      end

      it 'creates a skeet with photos' do
        expect(bluesky_instance).to receive(:skeet).with(
          rkey: kind_of(String),
          text: text,
          photos: array_including(
            hash_including(:url, :alt_text, :width, :height)
          ),
          in_reply_to: nil,
          quote: nil
        )

        described_class.new.perform(entry.id, text)
      end

      it 'writes at the record key it was given' do
        expect(bluesky_instance).to receive(:skeet).with(hash_including(rkey: 'abc1234567890'))

        described_class.new.perform(entry.id, text, nil, nil, 'abc1234567890')
      end

      it 'mints its own record key when called without one' do
        # A job enqueued before that argument existed arrives with four, and must still post.
        expect(bluesky_instance).to receive(:skeet).with(hash_including(rkey: kind_of(String)))

        described_class.new.perform(entry.id, text)
      end

      it 'updates entry with share tracking' do
        described_class.new.perform(entry.id, text)
        entry.reload

        expect(entry.last_shared_on_bluesky_at).not_to be_nil
        expect(entry.bluesky_shares_count).to eq(1)
      end

      it 'does not update share tracking for replies' do
        original_count = entry.bluesky_shares_count
        described_class.new.perform(entry.id, text, 'reply_uri')
        entry.reload

        expect(entry.bluesky_shares_count).to eq(original_count)
      end

      it 'does not update share tracking for quotes' do
        original_count = entry.bluesky_shares_count
        described_class.new.perform(entry.id, text, nil, 'quote_uri')
        entry.reload

        expect(entry.bluesky_shares_count).to eq(original_count)
      end

      it 'raises UnprocessedPhotoError when photos lack dimensions' do
        allow_any_instance_of(Entry).to receive(:photos_have_dimensions?).and_return(false)

        expect {
          described_class.new.perform(entry.id, text)
        }.to raise_error(UnprocessedPhotoError)
      end
    end

    context 'in non-production environment' do
      it 'returns early without calling Bluesky API' do
        expect(Bluesky).not_to receive(:from_social_account)
        described_class.new.perform(entry.id, text)
      end
    end

    context 'without connected account' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      end

      it 'returns early without calling Bluesky API' do
        expect(Bluesky).not_to receive(:from_social_account)
        described_class.new.perform(entry.id, text)
      end
    end

    context 'when entry is not a photo' do
      let(:non_photo_entry) { create(:entry, :published, blog: blog, user: user) }
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
      end

      it 'returns early without calling Bluesky API' do
        expect(Bluesky).not_to receive(:from_social_account)
        described_class.new.perform(non_photo_entry.id, text)
      end
    end

    context 'when entry does not exist' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      end

      it 'raises ActiveRecord::RecordNotFound' do
        expect(Bluesky).not_to receive(:from_social_account)
        expect { described_class.new.perform(999999, text) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with more than 4 photos' do
      let(:entry_with_many_photos) { create(:entry, :published, blog: blog, user: user) }
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
        # Create 6 photos for the entry
        6.times do
          photo = create(:photo, entry: entry_with_many_photos)
          attach_image_to_photo(photo)
        end

        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        allow(Bluesky).to receive(:from_social_account).with(bluesky_account).and_return(bluesky_instance)
        allow(bluesky_instance).to receive(:skeet).and_return({ 'uri' => post_uri })
      end

      it 'only includes first 4 photos' do
        expect(bluesky_instance).to receive(:skeet).with(
          hash_including(photos: satisfy { |photos| photos.size == 4 })
        )

        described_class.new.perform(entry_with_many_photos.id, text)
      end
    end
  end

  describe 'retry policy' do
    # sidekiq_retry_in lives in sidekiq_options, so a subclass block replaces the parent's rather
    # than adding to it. Both branches have to survive.
    def retry_in(exception, count = 0)
      described_class.sidekiq_retry_in_block.call(count, exception)
    end

    it 'discards a post that can never succeed' do
      expect(retry_in(BlueskyPermanentError.new)).to eq(:discard)
    end

    it 'discards credentials Bluesky refuses' do
      expect(retry_in(Bluesky::AuthenticationError.new)).to eq(:discard)
    end

    it 'still backs off for an unprocessed photo' do
      expect(retry_in(UnprocessedPhotoError.new, 3)).to eq(4)
    end

    it 'leaves everything else to Sidekiq' do
      expect(retry_in(StandardError.new)).to be_nil
    end
  end

  describe 'Sidekiq configuration' do
    it 'uses the high queue' do
      expect(described_class.sidekiq_options['queue']).to eq('high')
    end
  end
end
