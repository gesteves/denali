require 'rails_helper'

# Cloudflare caches these responses at the edge and CachePurgeJob invalidates
# them by tag, so the headers below are load-bearing rather than cosmetic: a
# missing Cache-Tag means a page nothing can purge, and a stray public directive
# means admin content in a shared cache.
RSpec.describe "Caching", type: :request do
  let!(:blog) { Blog.first || create(:blog) }
  let(:user) { create(:user) }

  def cache_control
    response.headers['Cache-Control']
  end

  # What Cloudflare caches on, as opposed to what browsers get. Cloudflare
  # consumes and strips this before the response reaches a client.
  def edge_cache_control
    response.headers['Cloudflare-CDN-Cache-Control']
  end

  def cache_tags
    response.headers['Cache-Tag'].to_s.split(',')
  end

  def published_entry
    entry = create(:entry, :published, :with_photo, blog: blog, user: user)
    entry.photos.each { |p| attach_image_to_photo(p) }
    entry
  end

  describe "public pages" do
    it "lets Cloudflare cache the page while browsers always revalidate" do
      published_entry
      get entries_path

      expect(cache_control).to include('public')
      expect(cache_control).to include('max-age=0')
      expect(edge_cache_control).to match(/max-age=\d+/)
    end

    it "keeps s-maxage off the response, since it would disable serving stale" do
      published_entry
      get entries_path

      expect(cache_control).not_to include('s-maxage')
      expect(cache_control).not_to include('must-revalidate')
      expect(cache_control).not_to include('proxy-revalidate')
    end

    it "lets the edge serve stale rather than block on the origin" do
      published_entry
      get entries_path

      expect(edge_cache_control).to match(/stale-while-revalidate=\d+/)
      expect(edge_cache_control).to match(/stale-if-error=\d+/)
    end

    it "takes the shared TTL from CACHE_TTL" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('CACHE_TTL', anything).and_return('600')

      published_entry
      get entries_path

      expect(edge_cache_control).to include('max-age=600')
    end

    it "tags the entry list so publishing invalidates it" do
      published_entry
      get entries_path
      expect(cache_tags).to eq([CacheTags::ENTRIES])
    end

    it "tags an entry with its own tag and the shared one" do
      entry = published_entry
      get entry.permalink_path

      expect(cache_tags).to contain_exactly(CacheTags.entry(entry.id), CacheTags::ENTRIES)
    end

    it "tags a tag archive with the tag's own tag" do
      entry = published_entry
      entry.update(tag_list: 'Cascades')

      get tag_path(tag: 'cascades')

      expect(cache_tags).to contain_exactly(CacheTags::ENTRIES, CacheTags.tag('cascades'))
    end

    it "tags the feed" do
      published_entry
      get feed_path(format: 'atom')
      expect(cache_tags).to eq([CacheTags::ENTRIES])
    end

    it "tags the sitemap" do
      published_entry
      get sitemap_path(format: 'xml')
      expect(cache_tags).to eq([CacheTags::ENTRIES])
    end

    # The short link's 301 is cached at the edge for a year and names a permalink
    # that moves when the title does, so it has to be purgeable.
    it "tags a short link with the entry it redirects to" do
      entry = published_entry
      get "/p/#{entry.id.to_s(36)}"

      expect(response).to have_http_status(:moved_permanently)
      expect(cache_tags).to eq([CacheTags.entry(entry.id)])
    end

    it "tags oembed with the entry it describes" do
      entry = published_entry
      get oembed_path(format: 'json', url: entry.permalink_url)

      expect(cache_tags).to eq([CacheTags.entry(entry.id)])
    end

    it "tags blog-driven pages so settings changes reach them" do
      get about_path
      expect(cache_tags).to eq([CacheTags::BLOG])

      get '/robots.txt'
      expect(cache_tags).to eq([CacheTags::BLOG])

      get manifest_path
      expect(cache_tags).to eq([CacheTags::BLOG])
    end
  end

  describe "conditional GETs" do
    it "serves an entry with a validator" do
      entry = published_entry
      get entry.permalink_path

      expect(response.headers['ETag']).to be_present
    end

    it "answers a matching If-None-Match with 304" do
      entry = published_entry
      get entry.permalink_path
      etag = response.headers['ETag']

      get entry.permalink_path, headers: { 'HTTP_IF_NONE_MATCH' => etag }

      expect(response).to have_http_status(:not_modified)
    end

    it "serves a fresh copy once the entry changes" do
      entry = published_entry
      get entry.permalink_path
      etag = response.headers['ETag']

      entry.touch
      get entry.permalink_path, headers: { 'HTTP_IF_NONE_MATCH' => etag }

      expect(response).to have_http_status(:success)
    end

    it "serves a fresh copy once the blog's settings change, which render here too" do
      entry = published_entry
      get entry.permalink_path
      etag = response.headers['ETag']

      blog.update_column(:settings_updated_at, entry.updated_at + 1.day)
      get entry.permalink_path, headers: { 'HTTP_IF_NONE_MATCH' => etag }

      expect(response).to have_http_status(:success)
    end

    it "moves Last-Modified when the settings change, since Cloudflare strips the ETag" do
      entry = published_entry
      get entry.permalink_path
      last_modified = response.headers['Last-Modified']

      blog.update_column(:settings_updated_at, entry.updated_at + 1.day)
      get entry.permalink_path, headers: { 'HTTP_IF_MODIFIED_SINCE' => last_modified }

      expect(response).to have_http_status(:success)
      expect(response.headers['Last-Modified']).not_to eq(last_modified)
    end

    it "leaves the validators alone when only an entry is touched" do
      entry = published_entry
      blog.update_column(:settings_updated_at, entry.updated_at - 1.day)
      get entry.permalink_path

      expect(response.headers['Last-Modified']).to eq(entry.updated_at.httpdate)
    end

    it "still redirects a non-canonical path rather than answering 304" do
      entry = published_entry
      get "/#{entry.id}/wrong-slug"

      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to(entry.permalink_url)
    end
  end

  describe "uncacheable responses" do
    it "never stores admin pages" do
      sign_in_as(user)
      get admin_entries_path

      expect(cache_control).to include('no-store')
      expect(cache_control).not_to include('public')
    end

    it "never stores the sign-in page" do
      get signin_path
      expect(cache_control).to include('no-store')
    end

    it "never stores GraphQL responses, whose cache key would miss Authorization" do
      post graphql_path, params: { query: '{ __typename }' }
      expect(cache_control).to include('no-store')
    end

    it "never stores a random entry, which would stop being random" do
      published_entry
      get random_path

      expect(cache_control).to include('no-store')
    end
  end

  describe "errors" do
    it "caches 404s briefly, to absorb scanners at the edge" do
      get '/nope-does-not-exist'

      expect(response).to have_http_status(:not_found)
      expect(edge_cache_control).to include('max-age=60')
    end
  end
end
