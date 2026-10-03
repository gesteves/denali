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

  describe "infinite scroll fragments" do
    before do
      allow_any_instance_of(Blog).to receive(:posts_per_page).and_return(1)
      2.times { create(:entry, :published, :with_photo, blog: blog, user: user).photos.each { |p| attach_image_to_photo(p) } }
    end

    it "serves the next page's entries as HTML without the layout" do
      get '/page/2.fragment'

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq('text/html')
      expect(response.body).not_to include('<html')
      expect(response.body).to include('<li')
    end

    it "serves tag pages the same way" do
      Entry.find_each { |e| e.update!(tag_list: 'mountains') }
      get '/tagged/mountains/page/2.fragment'

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('<html')
    end

    # A tab still running the old script asks for .js; a 404 ends its scrolling
    # instead of a redirect whose full page it would append.
    it "answers the old .js URLs with a 404" do
      get '/page/2.js'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "pagination bounds" do
    before do
      create(:entry, :published, :with_photo, blog: blog, user: user).photos.each { |p| attach_image_to_photo(p) }
    end

    it "makes each page its own canonical URL" do
      allow_any_instance_of(Blog).to receive(:posts_per_page).and_return(1)
      create(:entry, :published, :with_photo, blog: blog, user: user).photos.each { |p| attach_image_to_photo(p) }

      get '/page/2'

      expect(response.body).to match(%r{<link rel="canonical" href="[^"]+/page/2">})
    end

    # Kaminari treats page 0 as page 1, which put a duplicate of the home page at /page/0.
    it "returns 404 for page 0" do
      get '/page/0'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /search" do
    before do
      blog.update!(show_search: true)
      allow_any_instance_of(Blog).to receive(:has_search?).and_return(true)
    end

    it "returns 404 for pages before the first" do
      get search_path, params: { q: 'mountains', page: -1 }
      expect(response).to have_http_status(:not_found)
    end

    # Elasticsearch rejects from + size past 10,000 with an error.
    it "returns 404 for pages past what Elasticsearch can return" do
      expect(Entry).not_to receive(:search_with_tag_suggestions)
      get search_path, params: { q: 'mountains', page: (Entry::MAX_SEARCH_RESULTS / blog.posts_per_page) + 1 }
      expect(response).to have_http_status(:not_found)
    end

    it "returns an uncached 503 when Elasticsearch is down" do
      allow(Entry).to receive(:search_with_tag_suggestions).and_raise(Faraday::ConnectionFailed.new('connection refused'))
      allow(Bugsnag).to receive(:notify)

      get search_path, params: { q: 'mountains' }

      expect(response).to have_http_status(:service_unavailable)
      expect(response.headers['Cache-Control']).to include('no-store')
      expect(response.headers['Cloudflare-CDN-Cache-Control']).to be_nil
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

    it "redirects rss to atom feed" do
      get feed_path(format: 'rss')
      expect(response).to redirect_to(feed_url(format: 'atom', page: nil))
    end

    it "redirects unknown format to atom feed" do
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

    context "with multiple photos" do
      let(:entry) { create(:entry, :published, blog: blog, user: user) }

      before do
        2.times { |i| attach_image_to_photo(create(:photo, entry: entry, position: i + 1)) }
      end

      it "loads the first photo eagerly and the rest lazily" do
        get entry_long_path(entry.id, entry.slug)

        images = response.body.scan(/<img[^>]*entry__photo[^>]*>/)
        expect(images.length).to eq(2)
        expect(images.first).to include('loading="eager"').and include('fetchpriority="high"')
        expect(images.last).to include('loading="lazy"')
      end

      it "sizes the lazy photos from the media conditions, not the 300px auto default" do
        get entry_long_path(entry.id, entry.slug)

        images = response.body.scan(/<img[^>]*entry__photo[^>]*>/)
        images.each do |image|
          expect(image).to include('sizes="(min-width: 1696px) 1680px, calc(100vw - 16px)"')
          expect(image).not_to include('sizes="auto')
        end
      end
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

  describe "GET /p/:id (short link)" do
    it "redirects published entries to their permalink" do
      entry = create(:entry, :published, blog: blog, user: user)
      get "/p/#{entry.id.to_s(36)}"
      expect(response).to redirect_to(entry.permalink_url)
    end

    # Unpublished permalinks are preview URLs; IDs are sequential, so a short link
    # for an unpublished entry would let anyone walk the queue's previews.
    %i[queued draft].each do |status|
      it "returns 404 for #{status} entries" do
        entry = create(:entry, status, blog: blog, user: user)
        get "/p/#{entry.id.to_s(36)}"
        expect(response).to have_http_status(:not_found)
      end
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

    it "redirects rss to atom feed" do
      get tag_feed_path(tag: 'washington', format: 'rss')
      expect(response).to redirect_to(tag_feed_url(format: 'atom', page: nil, tag: 'washington'))
    end

    it "redirects unknown format to atom feed" do
      get tag_feed_path(tag: 'washington', format: 'foo')
      expect(response).to redirect_to(tag_feed_url(format: 'atom', page: nil, tag: 'washington'))
    end
  end
end
