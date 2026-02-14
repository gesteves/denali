require 'rails_helper'

RSpec.describe "Entries", type: :request do
  let!(:blog) { Blog.first || create(:blog) }
  let(:user) { create(:user) }

  before do
    blog.webhooks.destroy_all
    create_list(:webhook, 2, blog: blog)
  end

  describe "GET /entries (index)" do
    it "renders successfully" do
      entries = create_list(:entry, 3, :published, :with_photo, blog: blog, user: user)
      entries.each { |e| e.photos.each { |p| attach_image_to_photo(p) } }

      get entries_path
      expect(response).to have_http_status(:success)
    end

    it "redirects from unknown format" do
      entries = create_list(:entry, 3, :published, :with_photo, blog: blog, user: user)
      entries.each { |e| e.photos.each { |p| attach_image_to_photo(p) } }

      get entries_path(format: 'foo')
      expect(response).to redirect_to(entries_url)
    end
  end

  describe "GET /feed" do
    let!(:entries) { create_list(:entry, 2, :published, :with_photo, blog: blog, user: user) }

    before do
      # Set up images for all photos
      Photo.all.each do |photo|
        attach_image_to_photo(photo)
      end
    end

    it "generates atom feed" do
      get feed_path(format: 'atom')
      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq('application/atom+xml')
    end

    it "generates rss feed" do
      get feed_path(format: 'rss')
      expect(response).to have_http_status(:success)
    end

    it "redirects to atom feed from unknown format" do
      get feed_path(format: 'foo')
      expect(response).to redirect_to(feed_url(format: 'atom', page: nil))
    end
  end

  describe "GET /entry/:id (show)" do
    let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }

    before do
      entry.photos.each { |p| attach_image_to_photo(p) }
    end

    it "renders the entry page" do
      get entry_long_path(entry.id, entry.slug)
      expect(response).to have_http_status(:success)
    end

    it "redirects from unknown format" do
      get entry_long_path(entry.id, entry.slug, format: 'foo')
      expect(response).to redirect_to(entry.permalink_url)
    end
  end

  describe "GET /p/:preview_hash (preview)" do
    let(:queued_entry) { create(:entry, :queued, :with_photo, blog: blog, user: user, preview_hash: 'queued_hash_123') }
    let(:published_entry) { create(:entry, :published, :with_photo, blog: blog, user: user, preview_hash: 'published_hash_456') }

    before do
      queued_entry.photos.each { |p| attach_image_to_photo(p) }
      published_entry.photos.each { |p| attach_image_to_photo(p) }
    end

    it "shows preview page for unpublished entries" do
      get preview_entry_path(queued_entry.preview_hash, queued_entry.slug)
      expect(response).to have_http_status(:success)
    end

    it "redirects published entries to canonical URL" do
      get preview_entry_path(published_entry.preview_hash, published_entry.slug)
      expect(response).to redirect_to(published_entry.permalink_url)
    end
  end

  describe "GET /amp/:id (amp redirect)" do
    let(:entry) { create(:entry, :published, blog: blog, user: user) }

    it "redirects to canonical URL" do
      get entry_amp_path(
        year: entry.published_at.strftime('%Y'),
        month: entry.published_at.strftime('%-m'),
        day: entry.published_at.strftime('%-d'),
        id: entry.id,
        slug: entry.slug
      )
      expect(response).to redirect_to(entry.permalink_url)
    end
  end

  describe "GET /random" do
    it "redirects to a random entry" do
      create(:entry, :published, :with_photo, blog: blog, user: user)
      get random_path
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "GET /tagged/:tag (tagged)" do
    let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }

    before do
      entry.tag_list = 'washington'
      entry.save!
      entry.photos.each { |p| attach_image_to_photo(p) }
    end

    it "renders tag page" do
      get tag_path(tag: 'washington')
      expect(response).to have_http_status(:success)
    end

    it "redirects from unknown format" do
      get tag_path(tag: 'washington', format: 'foo')
      expect(response).to redirect_to(tag_url(format: 'html', page: nil, tag: 'washington'))
    end
  end

  describe "GET /tagged/:tag/feed (tag feed)" do
    let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }

    before do
      entry.tag_list = 'washington'
      entry.save!
      entry.photos.each { |p| attach_image_to_photo(p) }
    end

    it "renders atom feed" do
      get tag_feed_path(tag: 'washington', format: 'atom')
      expect(response).to have_http_status(:success)
    end

    it "renders rss feed" do
      get tag_feed_path(tag: 'washington', format: 'rss')
      expect(response).to have_http_status(:success)
    end

    it "redirects from unknown format" do
      get tag_feed_path(tag: 'washington', format: 'foo')
      expect(response).to redirect_to(tag_feed_url(format: 'atom', page: nil, tag: 'washington'))
    end
  end
end
