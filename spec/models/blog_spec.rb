require 'rails_helper'

RSpec.describe Blog, type: :model do
  let(:blog) { create(:blog, time_zone: 'Eastern Time (US & Canada)') }
  let(:user) { create(:user) }

  describe 'associations' do
    it { should have_many(:entries).dependent(:destroy) }
    it { should have_many(:webhooks).dependent(:destroy) }
    it { should have_many(:push_subscriptions).dependent(:destroy) }
    it { should have_many(:publish_schedules).dependent(:destroy) }
    it { should have_many(:tag_customizations).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:about) }
  end

  describe 'touching' do
    it 'creating an entry touches the blog' do
      initial_date = blog.updated_at
      sleep(0.01) # Ensure some time passes
      create(:entry, :published, blog: blog, user: user)
      blog.reload
      expect(blog.updated_at).not_to eq(initial_date)
    end
  end

  describe 'publish schedule tracking' do
    # Use unique hours for this test group to avoid global uniqueness conflicts
    let(:schedule_hour_1) { 8 }
    let(:schedule_hour_2) { 18 }
    let(:eastern_zone) { ActiveSupport::TimeZone['Eastern Time (US & Canada)'] }

    before do
      # Clean up any existing schedules with these hours
      PublishSchedule.where(hour: [schedule_hour_1, schedule_hour_2]).destroy_all
      create(:publish_schedule, blog: blog, hour: schedule_hour_1)
      create(:publish_schedule, blog: blog, hour: schedule_hour_2)
      blog.reload
    end

    describe '#past_publish_schedules_today' do
      it 'returns 0 at midnight' do
        travel_to eastern_zone.local(2019, 1, 19, 0, 0, 0) do
          expect(blog.past_publish_schedules_today.count).to eq(0)
        end
      end

      it 'returns 1 at 8:05am' do
        travel_to eastern_zone.local(2019, 1, 19, 8, 5, 0) do
          expect(blog.past_publish_schedules_today.count).to eq(1)
        end
      end

      it 'returns 2 at 6:59pm' do
        travel_to eastern_zone.local(2019, 1, 19, 18, 59, 0) do
          expect(blog.past_publish_schedules_today.count).to eq(2)
        end
      end
    end

    describe '#pending_publish_schedules_today' do
      it 'returns 2 at midnight' do
        travel_to eastern_zone.local(2019, 1, 19, 0, 0, 0) do
          expect(blog.pending_publish_schedules_today.count).to eq(2)
        end
      end

      it 'returns 1 at 8:05am' do
        travel_to eastern_zone.local(2019, 1, 19, 8, 5, 0) do
          expect(blog.pending_publish_schedules_today.count).to eq(1)
        end
      end

      it 'returns 0 at 6:59pm' do
        travel_to eastern_zone.local(2019, 1, 19, 18, 59, 0) do
          expect(blog.pending_publish_schedules_today.count).to eq(0)
        end
      end
    end

    describe '#time_to_publish_queued_entry?' do
      it 'returns false at midnight' do
        travel_to eastern_zone.local(2019, 1, 19, 0, 0, 0) do
          expect(blog.time_to_publish_queued_entry?).to be false
        end
      end

      it 'returns true at 8:05am' do
        travel_to eastern_zone.local(2019, 1, 19, 8, 5, 0) do
          expect(blog.time_to_publish_queued_entry?).to be true
        end
      end

      it 'returns true at 6:59pm' do
        travel_to eastern_zone.local(2019, 1, 19, 18, 59, 0) do
          expect(blog.time_to_publish_queued_entry?).to be true
        end
      end
    end

    describe '#publish_queued_entry!' do
      it 'publishes queued entries on schedule' do
        entry = create(:entry, :queued, blog: blog, user: user)
        entry.move_to_top
        queue_size = blog.entries.queued.count
        expect(entry.position).to eq(1)

        # At midnight - should not publish
        travel_to eastern_zone.local(2019, 1, 19, 0, 0, 0) do
          blog.publish_queued_entry!
          entry.reload
          expect(blog.entries.queued.count).to eq(queue_size)
          expect(entry.status).to eq('queued')
        end

        # At 8:05am - should publish
        travel_to eastern_zone.local(2019, 1, 19, 8, 5, 0) do
          blog.publish_queued_entry!
          entry.reload
          expect(blog.entries.queued.count).to eq(queue_size - 1)
          expect(entry.status).to eq('published')
        end
      end
    end
  end

  describe '#cache_tags' do
    it 'claims the site chrome and the lists its settings render into' do
      expect(blog.cache_tags).to eq([CacheTags::BLOG, CacheTags::ENTRIES])
    end

    it 'does not purge on save, since entries touch the blog constantly' do
      blog # create it before setting the expectation
      expect(CachePurgeJob).not_to receive(:enqueue)

      blog.touch
      blog.update(name: 'A new name')
    end
  end

  describe 'standard.site' do
    let(:account) { create(:social_account, provider: 'bluesky') }

    it 'names the account whose repo holds the records' do
      blog = create(:blog, standard_site_social_account: account)

      expect(blog.standard_site_account).to eq(account)
      expect(blog).to be_standard_site_enabled
    end

    it 'names none when the blog picked no account' do
      blog = create(:blog)

      expect(blog.standard_site_account).to be_nil
      expect(blog).not_to be_standard_site_enabled
    end

    it 'names none when the account is for another network' do
      blog = create(:blog, standard_site_social_account: create(:social_account, provider: 'mastodon'))

      expect(blog.standard_site_account).to be_nil
    end

    it 'names none when the account has no credentials' do
      account.update_columns(access_token: nil)

      expect(create(:blog, standard_site_social_account: account).standard_site_account).to be_nil
    end

    # ⚠️ Each document names the publication by an at:// URI holding the DID, so they go invalid on
    # their own when the account changes. The publication's own fingerprint doesn't: left in place
    # it would report "unchanged" forever and never sync to the new repo.
    it 'forgets the old repo when the account changes' do
      blog = create(:blog, :on_standard_site, standard_site_fingerprint: 'stale')

      blog.update!(standard_site_social_account: account)

      expect(blog.standard_site_did).to be_nil
      expect(blog.standard_site_fingerprint).to be_nil
    end

    # ⚠️ `belongs_to :blog, touch: true` on Entry updates a blog row every time an entry is saved.
    # A callback reading the blog's dirty tracking there sees whatever the in-memory blog was last
    # really saved with, which for a freshly built one is its create — so this cleared the DID on
    # an unrelated save until the check moved to before_update.
    it 'keeps the repo when an entry save touches the blog' do
      blog = create(:blog, :on_standard_site, standard_site_fingerprint: 'current')

      create(:entry, :published, blog: blog, user: create(:user))

      expect(blog.reload.standard_site_did).to be_present
      expect(blog.standard_site_fingerprint).to eq('current')
    end

    it 'has no publication URI before it has ever synced' do
      expect(create(:blog).standard_site_publication_uri).to be_nil
    end
  end
end
