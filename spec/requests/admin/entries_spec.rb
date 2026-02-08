require 'rails_helper'

RSpec.describe "Admin::Entries", type: :request do
  let(:user) { create(:user, uid: 'test_uid_123') }
  let!(:blog) { Blog.first || create(:blog) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }

  before do
    # Ensure exactly 2 webhooks for the blog
    blog.webhooks.destroy_all
    create_list(:webhook, 2, blog: blog)
    # Sign in
    sign_in_as(user)
    # Set up entry with tag and photo
    entry.photos.each { |p| attach_image_to_photo(p) }
    entry.tag_list = 'Washington'
    entry.save!
  end

  describe "GET /admin/entries (index)" do
    it "renders successfully" do
      get admin_entries_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /admin/entries/queued" do
    it "renders successfully" do
      get queued_admin_entries_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /admin/entries/drafts" do
    it "renders successfully" do
      get drafts_admin_entries_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /admin/entries/tagged/:tag" do
    it "renders successfully" do
      get admin_tagged_entries_path(tag: 'washington')
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /admin/entries/:id (show)" do
    it "renders successfully" do
      get admin_entry_path(entry)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /admin/entries/new" do
    it "renders successfully" do
      get new_admin_entry_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /admin/entries/:id/edit" do
    it "renders successfully" do
      get edit_admin_entry_path(entry)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /admin/entries/:id/crops" do
    let(:entry_with_photo) { create(:entry, :published, :with_photo, blog: blog, user: user) }

    before do
      entry_with_photo.photos.each { |p| attach_image_to_photo(p) }
    end

    it "renders successfully" do
      get crops_admin_entry_path(entry_with_photo)
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /admin/entries/:id/queue" do
    let(:draft_entry) { create(:entry, :draft, blog: blog, user: user) }

    it "queues the entry" do
      patch queue_admin_entry_path(draft_entry)
      draft_entry.reload
      expect(draft_entry).to be_is_queued
      expect(draft_entry.position).not_to be_nil
    end
  end

  describe "PATCH /admin/entries/:id/draft" do
    let(:queued_entry) { create(:entry, :queued, blog: blog, user: user) }

    it "drafts the entry" do
      patch draft_admin_entry_path(queued_entry)
      queued_entry.reload
      expect(queued_entry).to be_is_draft
      expect(queued_entry.position).to be_nil
    end
  end

  describe "PATCH /admin/entries/:id/publish" do
    let(:draft_entry) { create(:entry, :draft, blog: blog, user: user) }

    it "publishes the entry" do
      patch publish_admin_entry_path(draft_entry)
      draft_entry.reload
      expect(draft_entry).to be_is_published
      expect(draft_entry.position).to be_nil
    end
  end

  describe "POST /admin/entries (create)" do
    let(:image_file) { fixture_file_upload(Rails.root.join('spec/fixtures/images/rusty.jpg'), 'image/jpeg') }

    before do
      # Clear any jobs from previous setup
      WebhookJob.jobs.clear
      FlickrJob.jobs.clear
    end

    it "creates published entries" do
      initial_webhook_count = WebhookJob.jobs.size
      initial_flickr_count = FlickrJob.jobs.size

      expect {
        post admin_entries_path, params: {
          entry: {
            title: 'Published',
            status: 'published',
            photos_attributes: [{ image: image_file }],
            post_to_flickr: false
          }
        }
      }.to change(Entry, :count).by(1)

      expect(FlickrJob.jobs.size - initial_flickr_count).to eq(0)
      expect(WebhookJob.jobs.size - initial_webhook_count).to eq(2)

      new_entry = Entry.last
      expect(new_entry).to be_is_published
      expect(new_entry.photos.count).to eq(1)
      expect(new_entry.photos.first.image).to be_attached
    end

    it "creates draft entries" do
      initial_webhook_count = WebhookJob.jobs.size
      initial_flickr_count = FlickrJob.jobs.size

      expect {
        post admin_entries_path, params: {
          entry: {
            title: 'Draft',
            status: 'draft',
            photos_attributes: [{ image: image_file }]
          }
        }
      }.to change(Entry, :count).by(1)

      expect(FlickrJob.jobs.size - initial_flickr_count).to eq(0)
      expect(WebhookJob.jobs.size - initial_webhook_count).to eq(0)

      new_entry = Entry.last
      expect(new_entry).to be_is_draft
    end

    it "creates queued entries" do
      initial_webhook_count = WebhookJob.jobs.size
      initial_flickr_count = FlickrJob.jobs.size

      expect {
        post admin_entries_path, params: {
          entry: {
            title: 'Queued',
            status: 'queued',
            photos_attributes: [{ image: image_file }]
          }
        }
      }.to change(Entry, :count).by(1)

      expect(FlickrJob.jobs.size - initial_flickr_count).to eq(0)
      expect(WebhookJob.jobs.size - initial_webhook_count).to eq(0)

      new_entry = Entry.last
      expect(new_entry).to be_is_queued
      expect(new_entry.position).not_to be_nil
    end
  end

  describe "PATCH /admin/entries/:id (update)" do
    it "updates the entry" do
      patch admin_entry_path(entry), params: { entry: { title: 'Updated Title' } }
      expect(response).to redirect_to(admin_entry_path(entry))
      entry.reload
      expect(entry.title).to eq('Updated Title')
    end

    it "updates modified_at" do
      original_modified_at = entry.modified_at
      sleep(0.01)
      patch admin_entry_path(entry), params: { entry: { title: 'Updated' } }
      entry.reload
      expect(entry.modified_at).not_to eq(original_modified_at)
    end
  end

  describe "GET /admin/entries/queued/organize" do
    it "renders successfully" do
      get admin_entries_queued_organize_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /admin/entries/queued/update" do
    it "properly sorts queue" do
      entry1 = create(:entry, :queued, blog: blog, user: user, position: 1)
      entry2 = create(:entry, :queued, blog: blog, user: user, position: 2)
      entry3 = create(:entry, :queued, blog: blog, user: user, position: 3)
      entry4 = create(:entry, :queued, blog: blog, user: user, position: 4)

      ids = [entry4.id, entry3.id, entry2.id, entry1.id]
      post admin_entries_queued_update_path, params: { entry_ids: ids }, as: :json

      expect(response).to have_http_status(:success)

      [entry1, entry2, entry3, entry4].each(&:reload)

      expect(entry4.position).to eq(1)
      expect(entry3.position).to eq(2)
      expect(entry2.position).to eq(3)
      expect(entry1.position).to eq(4)
    end
  end
end
