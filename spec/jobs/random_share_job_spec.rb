require 'rails_helper'

RSpec.describe RandomShareJob, type: :worker do
  let!(:blog) { Blog.first || create(:blog) }
  let(:user) { create(:user) }

  before do
    allow(Rails.env).to receive(:production?).and_return(true)
  end

  describe '#perform' do
    it 'returns early in non-production environment' do
      allow(Rails.env).to receive(:production?).and_return(false)
      expect(BlueskyJob).not_to receive(:perform_in)
      described_class.new.perform([], ['Bluesky'])
    end

    it 'returns early when platforms array is empty' do
      expect(BlueskyJob).not_to receive(:perform_in)
      described_class.new.perform([], [])
    end

    it 'returns early when entry was recently published' do
      create(:entry, :published, blog: blog, user: user, published_at: 30.minutes.ago)
      expect(BlueskyJob).not_to receive(:perform_in)
      described_class.new.perform([], ['Bluesky'])
    end

    it 'returns early when entry was recently shared' do
      create(:entry, :published, blog: blog, user: user, published_at: 1.year.ago, last_shared_on_bluesky_at: 30.minutes.ago)
      expect(BlueskyJob).not_to receive(:perform_in)
      described_class.new.perform([], ['Bluesky'])
    end

    context 'with eligible entries' do
      let!(:old_entry) do
        create(:entry, :published, :with_photo, blog: blog, user: user,
               published_at: 2.years.ago,
               last_shared_on_bluesky_at: 2.years.ago,
               last_shared_on_mastodon_at: 2.years.ago,
               post_to_bluesky: true,
               post_to_mastodon: true,
               valid_bluesky_caption: true,
               valid_mastodon_caption: true,
               bluesky_shares_count: 0,
               mastodon_shares_count: 0)
      end

      before do
        old_entry.photos.each { |p| attach_image_to_photo(p) }
        allow_any_instance_of(Entry).to receive(:bluesky_caption).and_return('Test')
        allow_any_instance_of(Entry).to receive(:mastodon_caption).and_return('Test')
        allow_any_instance_of(Entry).to receive(:instagram_caption).and_return('Test')
        allow_any_instance_of(Entry).to receive(:threads_caption).and_return('Test')
      end

      it 'enqueues BlueskyJob for Bluesky platform' do
        # Clear any existing jobs
        BlueskyJob.jobs.clear

        # Let real scopes work - old_entry should be eligible
        described_class.new.perform([], ['Bluesky'])

        expect(BlueskyJob.jobs.size).to eq(1)
      end

      it 'enqueues MastodonJob for Mastodon platform' do
        # Clear any existing jobs
        MastodonJob.jobs.clear

        # Let real scopes work - old_entry should be eligible
        described_class.new.perform([], ['Mastodon'])

        expect(MastodonJob.jobs.size).to eq(1)
      end
    end
  end
end
