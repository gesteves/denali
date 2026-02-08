require 'rails_helper'

RSpec.describe CaptionValidityJob, type: :worker do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }

  before do
    entry.photos.each { |p| attach_image_to_photo(p) }
  end

  describe '#perform' do
    it 'updates caption validity flags' do
      allow(Bluesky).to receive(:valid_post_length?).and_return(true)
      allow_any_instance_of(Entry).to receive(:bluesky_caption).and_return('Short caption')
      allow_any_instance_of(Entry).to receive(:mastodon_caption).and_return('Short caption')
      allow_any_instance_of(Entry).to receive(:instagram_caption).and_return('Short caption')
      allow_any_instance_of(Entry).to receive(:threads_caption).and_return('Short caption')

      described_class.new.perform(entry.id)
      entry.reload

      expect(entry.valid_bluesky_caption).to be true
      expect(entry.valid_mastodon_caption).to be true
      expect(entry.valid_instagram_caption).to be true
      expect(entry.valid_threads_caption).to be true
    end

    it 'marks mastodon caption as invalid when too long' do
      allow(Bluesky).to receive(:valid_post_length?).and_return(true)
      allow_any_instance_of(Entry).to receive(:bluesky_caption).and_return('Short')
      allow_any_instance_of(Entry).to receive(:mastodon_caption).and_return('x' * 501)
      allow_any_instance_of(Entry).to receive(:instagram_caption).and_return('Short')
      allow_any_instance_of(Entry).to receive(:threads_caption).and_return('Short')

      described_class.new.perform(entry.id)
      entry.reload

      expect(entry.valid_mastodon_caption).to be false
    end

    it 'marks instagram caption as invalid when too long' do
      allow(Bluesky).to receive(:valid_post_length?).and_return(true)
      allow_any_instance_of(Entry).to receive(:bluesky_caption).and_return('Short')
      allow_any_instance_of(Entry).to receive(:mastodon_caption).and_return('Short')
      allow_any_instance_of(Entry).to receive(:instagram_caption).and_return('x' * 2201)
      allow_any_instance_of(Entry).to receive(:threads_caption).and_return('Short')

      described_class.new.perform(entry.id)
      entry.reload

      expect(entry.valid_instagram_caption).to be false
    end

    it 'handles deleted entries gracefully' do
      entry_id = entry.id
      entry.destroy

      expect {
        described_class.new.perform(entry_id)
      }.not_to raise_error
    end
  end
end
