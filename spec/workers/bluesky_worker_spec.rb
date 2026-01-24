require 'rails_helper'

RSpec.describe BlueskyWorker, type: :worker do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }

  before do
    entry.photos.each { |p| attach_image_to_photo(p) }
    create_list(:webhook, 2, blog: blog)
  end

  describe '#perform' do
    let(:text) { 'Test caption for Bluesky' }

    context 'in production environment with credentials' do
      let(:bluesky_instance) { instance_double(Bluesky) }

      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('BLUESKY_BASE_URL').and_return('https://bsky.social')
        allow(ENV).to receive(:[]).with('BLUESKY_EMAIL').and_return('test@example.com')
        allow(ENV).to receive(:[]).with('BLUESKY_PASSWORD').and_return('password')
        allow(Bluesky).to receive(:new).and_return(bluesky_instance)
        allow(bluesky_instance).to receive(:skeet)
      end

      it 'creates a skeet with photos' do
        expect(bluesky_instance).to receive(:skeet).with(
          text: text,
          photos: array_including(
            hash_including(:url, :alt_text, :width, :height)
          ),
          in_reply_to: nil,
          quote: nil
        )

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
        expect(Bluesky).not_to receive(:new)
        described_class.new.perform(entry.id, text)
      end
    end

    context 'without credentials' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('BLUESKY_BASE_URL').and_return('')
      end

      it 'returns early without calling Bluesky API' do
        expect(Bluesky).not_to receive(:new)
        described_class.new.perform(entry.id, text)
      end
    end
  end

  describe 'Sidekiq configuration' do
    it 'uses the high queue' do
      expect(described_class.sidekiq_options['queue']).to eq('high')
    end
  end
end
