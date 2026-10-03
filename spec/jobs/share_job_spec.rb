require 'rails_helper'

RSpec.describe ShareJob do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
  let(:job) { described_class.new }

  before do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
  end

  it 'gives up after six hours rather than retrying for weeks' do
    expect(described_class.get_sidekiq_options['retry_for']).to eq(6.hours.to_i)
    expect(MastodonJob.get_sidekiq_options['retry_for']).to eq(6.hours.to_i)
    expect(MastodonJob.get_sidekiq_options['queue']).to eq('high')
  end

  describe '.available_for?' do
    it 'needs every network to say' do
      expect { described_class.available_for?(user) }.to raise_error(NotImplementedError)
    end

    {
      BlueskyJob => :bluesky,
      MastodonJob => :mastodon,
      InstagramJob => :instagram,
      ThreadsJob => :threads
    }.each do |job_class, provider|
      describe job_class do
        before do
          allow(ENV).to receive(:[]).and_call_original
          %w[INSTAGRAM_APP_ID INSTAGRAM_APP_SECRET THREADS_APP_ID THREADS_APP_SECRET].each do |key|
            allow(ENV).to receive(:[]).with(key).and_return('set')
          end
        end

        it "is available with a #{provider} account" do
          create(:social_account, provider, user:)
          expect(job_class.available_for?(user)).to be true
        end

        it "isn't without one" do
          expect(job_class.available_for?(user)).to be false
          expect(job_class.available_for?(nil)).to be false
        end
      end
    end

    it "isn't available on Meta's networks without the app's credentials" do
      allow(ENV).to receive(:[]).and_call_original
      %w[INSTAGRAM_APP_ID THREADS_APP_ID].each { |key| allow(ENV).to receive(:[]).with(key).and_return(nil) }
      create(:social_account, :instagram, user:)
      create(:social_account, :threads, user:)

      expect(InstagramJob.available_for?(user)).to be false
      expect(ThreadsJob.available_for?(user)).to be false
    end
  end

  describe '#shareable_entry' do
    it 'returns nothing outside production' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('test'))
      expect(job.send(:shareable_entry, entry.id)).to be_nil
    end

    it 'returns nothing for an entry that is gone or unpublished' do
      expect(job.send(:shareable_entry, 999_999)).to be_nil
      entry.update_columns(status: 'draft')
      expect(job.send(:shareable_entry, entry.id)).to be_nil
    end

    it 'analyzes photos that have not been analyzed yet' do
      photo = entry.photos.first
      allow_any_instance_of(Photo).to receive(:ensure_analyzed!) { attach_image_to_photo(photo) }

      expect(job.send(:shareable_entry, entry.id)).to eq(entry)
    end

    it 'waits for photos it still cannot measure' do
      allow_any_instance_of(Photo).to receive(:ensure_analyzed!)
      expect { job.send(:shareable_entry, entry.id) }.to raise_error(UnprocessedPhotoError)
    end
  end

  describe '#record_share' do
    it 'counts the share and stamps the time' do
      freeze_time do
        job.send(:record_share, entry, 'mastodon')
        entry.reload

        expect(entry.mastodon_shares_count).to eq(1)
        expect(entry.last_shared_on_mastodon_at).to eq(Time.current)
      end
    end

    # A read-then-write would lose one of two shares that read the same count.
    it 'increments in the database rather than from a stale copy' do
      stale = Entry.find(entry.id)
      job.send(:record_share, entry, 'bluesky')
      job.send(:record_share, stale, 'bluesky')

      expect(entry.reload.bluesky_shares_count).to eq(2)
    end
  end
end
