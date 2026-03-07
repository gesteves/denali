require 'rails_helper'

RSpec.describe Entry, type: :model do
  let(:user) { create(:user) }
  let(:blog) { create(:blog) }

  describe 'associations' do
    it { should belong_to(:blog) }
    it { should belong_to(:user) }
    it { should have_many(:photos).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:title) }

    it 'should not save entry without title' do
      entry = Entry.new(body: 'Test', blog: blog, user: user)
      expect(entry.save).to be false
    end
  end

  describe 'before_save callbacks' do
    it 'should set slug before saving' do
      title = 'This should be in my title'
      entry = Entry.new(title: title, body: 'Whatever.', blog: blog, user: user)
      entry.save
      expect(entry.slug).to eq('this-should-be-in-my-title')
    end

    it 'should set preview hash before saving' do
      entry = Entry.new(title: 'This is my title', body: 'Whatever.', blog: blog, user: user)
      entry.save
      expect(entry.preview_hash).not_to be_nil
    end
  end

  describe 'status management' do
    context 'when draft' do
      it 'should be draft' do
        entry = create(:entry, :draft, blog: blog, user: user)
        expect(entry).to be_is_draft
        expect(FlickrJob.jobs.size).to eq(0)
        expect(WebhookJob.jobs.size).to eq(0)
      end
    end

    context 'when queued' do
      it 'should be queued' do
        entry = create(:entry, :queued, blog: blog, user: user)
        expect(entry).to be_is_queued
        expect(FlickrJob.jobs.size).to eq(0)
        expect(WebhookJob.jobs.size).to eq(0)
      end
    end

    context 'when published' do
      before do
        create_list(:webhook, 2, blog: blog)
      end

      it 'should be published' do
        entry = create(:entry, status: 'published', blog: blog, user: user, post_to_flickr: false)
        expect(entry).to be_is_published
        expect(FlickrJob.jobs.size).to eq(0)
        expect(WebhookJob.jobs.size).to eq(2)
      end
    end
  end

  describe 'status transitions' do
    before do
      create_list(:webhook, 2, blog: blog)
    end

    it 'should change drafts to published' do
      entry = create(:entry, :draft, blog: blog, user: user)
      entry.publish
      expect(entry).to be_is_published
    end

    it 'should change queued to published' do
      entry = create(:entry, :queued, blog: blog, user: user)
      entry.publish
      expect(entry).to be_is_published
    end

    it 'should change drafts to queued' do
      entry = create(:entry, :draft, blog: blog, user: user)
      entry.queue
      expect(entry).to be_is_queued
    end

    it 'should change queued to draft' do
      entry = create(:entry, :queued, blog: blog, user: user)
      entry.draft
      expect(entry).to be_is_draft
    end

    it 'should not change published to queued' do
      entry = create(:entry, :published, blog: blog, user: user)
      entry.queue
      expect(entry).to be_is_published
    end

    it 'should not change published to draft' do
      entry = create(:entry, :published, blog: blog, user: user)
      entry.draft
      expect(entry).to be_is_published
    end
  end

  describe 'published_at and modified_at timestamps' do
    before do
      create_list(:webhook, 2, blog: blog)
    end

    it 'publish should set published_at & modified_at' do
      entry = create(:entry, :queued, blog: blog, user: user)
      expect(entry.published_at).to be_nil
      expect(entry.modified_at).to be_nil
      entry.publish
      expect(entry.published_at).not_to be_nil
      expect(entry.modified_at).not_to be_nil
    end

    it 'draft should not set published_at' do
      entry = create(:entry, :queued, blog: blog, user: user)
      entry.draft
      expect(entry.published_at).to be_nil
    end

    it 'queue should not set published_at' do
      entry = create(:entry, :draft, blog: blog, user: user)
      entry.queue
      expect(entry.published_at).to be_nil
    end

    it 'published_at should not change on subsequent publishes' do
      entry = create(:entry, :queued, blog: blog, user: user)
      entry.publish
      published_at = entry.published_at
      entry.publish
      expect(entry.published_at).to eq(published_at)
    end
  end

  describe 'job enqueueing' do
    before do
      create_list(:webhook, 2, blog: blog)
    end

    it 'publish should enqueue webhook jobs' do
      entry = create(:entry, :queued, blog: blog, user: user, post_to_flickr: false)
      expect(FlickrJob.jobs.size).to eq(0)
      expect(WebhookJob.jobs.size).to eq(0)
      entry.publish
      expect(FlickrJob.jobs.size).to eq(0)
      expect(WebhookJob.jobs.size).to eq(2)
    end

    it 'changing drafts to queued should not enqueue jobs' do
      entry = create(:entry, :draft, blog: blog, user: user)
      entry.queue
      expect(FlickrJob.jobs.size).to eq(0)
      expect(WebhookJob.jobs.size).to eq(0)
    end

    it 'changing queued to draft should not enqueue jobs' do
      entry = create(:entry, :queued, blog: blog, user: user)
      entry.draft
      expect(FlickrJob.jobs.size).to eq(0)
      expect(WebhookJob.jobs.size).to eq(0)
    end
  end

  describe 'position management' do
    it 'queuing should set a position' do
      entry = create(:entry, :queued, blog: blog, user: user)
      expect(entry.position).not_to be_nil
    end

    it 'publishing a queued post should clear the position' do
      create_list(:webhook, 2, blog: blog)
      entry = create(:entry, :queued, blog: blog, user: user)
      expect(entry.position).not_to be_nil
      entry.publish
      expect(entry.position).to be_nil
    end

    it 'publish should not set position' do
      create_list(:webhook, 2, blog: blog)
      entry = create(:entry, :queued, blog: blog, user: user)
      entry.publish
      expect(entry.position).to be_nil
    end

    it 'draft should not set position' do
      entry = create(:entry, :queued, blog: blog, user: user)
      entry.draft
      expect(entry.position).to be_nil
    end

    it 'queue should set position' do
      entry = create(:entry, :draft, blog: blog, user: user)
      entry.queue
      expect(entry.position).not_to be_nil
    end

    it 'entry positioning should work' do
      # Clear any existing queued entries to ensure clean position state
      Entry.queued.destroy_all

      entry_1 = create(:entry, :queued, blog: blog, user: user, position: 1)
      entry_2 = create(:entry, :queued, blog: blog, user: user)
      entry_3 = create(:entry, :queued, blog: blog, user: user)

      entry_1.move_lower
      expect(entry_1.position).to eq(2)

      entry_1.move_higher
      expect(entry_1.position).to eq(1)

      entry_1.move_to_bottom
      expect(entry_1.position).to eq(3)

      entry_1.move_to_top
      expect(entry_1.position).to eq(1)
    end
  end

  describe 'formatting' do
    it 'entry formatting should work' do
      entry = Entry.new(
        title: "This is the *title* you're looking for & stuff",
        body: "This is the *body* you're looking for & stuff.",
        status: 'queued',
        blog: blog,
        user: user
      )
      entry.save
      # SmartyPants converts ' to ' (RIGHT SINGLE QUOTATION MARK U+2019)
      expect(entry.plain_title).to eq("This is the title you\u2019re looking for & stuff")
      expect(entry.formatted_body).to eq("<p>This is the <em>body</em> you&rsquo;re looking for &amp; stuff.</p>\n")
      expect(entry.plain_body).to eq("This is the body you\u2019re looking for & stuff.")
    end
  end

  describe 'tag customizations' do
    describe 'flickr_groups' do
      it 'returns groups when all tags match' do
        # Create tag customization without default tags, only with 'tag c' and 'tag d'
        tag_customization = TagCustomization.new(flickr_groups: 'https://flickr.com/whatever/', blog: blog)
        tag_customization.tag_list.add('tag c', 'tag d')
        tag_customization.save!

        entry = create(:entry, :queued, blog: blog, user: user)
        expect(entry.flickr_groups).to be_empty

        entry.add_tags('tag c')
        entry.reload
        expect(entry.flickr_groups).to be_empty

        entry.add_tags('tag d')
        entry.reload
        expect(entry.flickr_groups).not_to be_empty
      end
    end

    describe 'flickr_albums' do
      it 'returns albums when all tags match' do
        # Create tag customization without default tags, only with 'tag c' and 'tag d'
        tag_customization = TagCustomization.new(flickr_albums: 'https://flickr.com/whatever/', blog: blog)
        tag_customization.tag_list.add('tag c', 'tag d')
        tag_customization.save!

        entry = create(:entry, :queued, blog: blog, user: user)
        expect(entry.flickr_albums).to be_empty

        entry.add_tags('tag c')
        entry.reload
        expect(entry.flickr_albums).to be_empty

        entry.add_tags('tag d')
        entry.reload
        expect(entry.flickr_albums).not_to be_empty
      end
    end
  end

  describe 'adding tags' do
    it 'should properly categorize tags' do
      entry = create(:entry, :queued, blog: blog, user: user)
      entry.tag_list = 'Panda'
      entry.location_list = 'Washington'
      entry.equipment_list = 'Nikon'
      entry.style_list = 'Black & White'
      entry.save!
      entry.reload

      entry.add_tags('Panda, Washington, Mammal')
      expect(entry.tag_list).to include('Panda')
      expect(entry.location_list).to include('Washington')
      expect(entry.style_list).to include('Black & White')

      expect(entry.tag_list).to include('Mammal')
      expect(entry.tag_list).not_to include('Washington')
    end
  end

  describe '.published_today' do
    it 'returns entries published today' do
      expect(Entry.published_today.count).to eq(0)
      create_list(:webhook, 2, blog: blog)
      entry = create(:entry, :queued, blog: blog, user: user)
      entry.publish
      expect(Entry.published_today.count).to eq(1)
    end
  end

  describe '.find_by_url' do
    before do
      create_list(:webhook, 2, blog: blog)
    end

    it 'returns the correct entry for a valid url' do
      entry = create(:entry, :published, blog: blog, user: user)
      found_entry = Entry.find_by_url(url: entry.permalink_url)
      expect(found_entry).to eq(entry)
    end

    it 'raises RecordNotFound for invalid urls' do
      expect { Entry.find_by_url(url: 'foo') }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '.eligible_for_random_share' do
    let!(:shareable_entry) do
      create(:entry, :published, blog: blog, user: user,
             published_at: 2.years.ago,
             post_to_bluesky: true,
             post_to_mastodon: true,
             post_to_instagram: true,
             post_to_threads: true,
             last_shared_on_bluesky_at: 2.years.ago,
             last_shared_on_mastodon_at: 2.years.ago,
             last_shared_on_instagram_at: 2.years.ago,
             last_shared_on_threads_at: 2.years.ago,
             bluesky_shares_count: 0,
             mastodon_shares_count: 0,
             instagram_shares_count: 0,
             threads_shares_count: 0)
    end

    it 'returns published entries shareable on Bluesky' do
      results = Entry.eligible_for_random_share(platform: 'Bluesky')
      expect(results).to include(shareable_entry)
    end

    it 'returns published entries shareable on Mastodon' do
      results = Entry.eligible_for_random_share(platform: 'Mastodon')
      expect(results).to include(shareable_entry)
    end

    it 'returns published entries shareable on Instagram' do
      results = Entry.eligible_for_random_share(platform: 'Instagram')
      expect(results).to include(shareable_entry)
    end

    it 'returns published entries shareable on Threads' do
      results = Entry.eligible_for_random_share(platform: 'Threads')
      expect(results).to include(shareable_entry)
    end

    it 'excludes entries shared within not_shared_in period' do
      shareable_entry.update!(last_shared_on_bluesky_at: 2.months.ago)
      results = Entry.eligible_for_random_share(platform: 'Bluesky', not_shared_in: 1.month)
      expect(results).to include(shareable_entry)

      shareable_entry.update!(last_shared_on_bluesky_at: 1.day.ago)
      results = Entry.eligible_for_random_share(platform: 'Bluesky', not_shared_in: 1.month)
      expect(results).not_to include(shareable_entry)
    end

    it 'filters by tags when provided' do
      shareable_entry.tag_list = 'Landscapes'
      shareable_entry.save!

      results = Entry.eligible_for_random_share(platform: 'Bluesky', tags: ['Landscapes'])
      expect(results).to include(shareable_entry)

      results = Entry.eligible_for_random_share(platform: 'Bluesky', tags: ['Wildlife'])
      expect(results).not_to include(shareable_entry)
    end

    it 'excludes entries with excluded tags' do
      shareable_entry.tag_list = 'Cherry Blossoms'
      shareable_entry.save!

      results = Entry.eligible_for_random_share(platform: 'Bluesky', excluded_tags: ['Cherry Blossoms'])
      expect(results).not_to include(shareable_entry)
    end

    it 'returns nil for unknown platform' do
      results = Entry.eligible_for_random_share(platform: 'Twitter')
      expect(results).to be_nil
    end
  end

  describe 'territories' do
    let(:territory1) { create(:territory, name: 'Shoshone-Bannock') }
    let(:territory2) { create(:territory, name: 'Eastern Shoshone') }
    let(:territory3) { create(:territory, name: 'Cheyenne') }

    it 'returns nil when show_location is false' do
      entry = create(:entry, blog: blog, user: user, show_location: false)
      photo = create(:photo, entry: entry)
      create(:photo_territory, photo: photo, territory: territory1)

      expect(entry.territories).to be_nil
      expect(entry.territory_list).to be_nil
    end

    it 'returns empty when no territories' do
      entry = create(:entry, blog: blog, user: user, show_location: true)
      create(:photo, entry: entry)

      expect(entry.territories).to be_empty
      expect(entry.territory_list).to be_nil
    end

    it 'formats single territory correctly' do
      entry = create(:entry, blog: blog, user: user, show_location: true)
      photo = create(:photo, entry: entry)
      create(:photo_territory, photo: photo, territory: territory1)
      entry.reload

      expect(entry.territory_list).to eq('Shoshone-Bannock')
    end

    it 'formats two territories correctly' do
      entry = create(:entry, blog: blog, user: user, show_location: true)
      photo = create(:photo, entry: entry)
      create(:photo_territory, photo: photo, territory: territory1)
      create(:photo_territory, photo: photo, territory: territory2)
      entry.reload

      expect(entry.territory_list).to eq('Shoshone-Bannock and Eastern Shoshone')
    end

    it 'formats three territories correctly' do
      entry = create(:entry, blog: blog, user: user, show_location: true)
      photo = create(:photo, entry: entry)
      create(:photo_territory, photo: photo, territory: territory1)
      create(:photo_territory, photo: photo, territory: territory2)
      create(:photo_territory, photo: photo, territory: territory3)
      entry.reload

      expect(entry.territory_list).to eq('Shoshone-Bannock, Eastern Shoshone, and Cheyenne')
    end
  end
end
