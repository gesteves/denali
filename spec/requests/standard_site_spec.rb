require 'rails_helper'

RSpec.describe 'standard.site verification', type: :request do
  let(:did) { 'did:plc:abc123' }
  let!(:blog) { create(:blog, standard_site_did: did) }
  let(:user) { create(:user) }

  describe 'GET /.well-known/site.standard.publication' do
    it 'returns the publication URI as plain text' do
      get '/.well-known/site.standard.publication'

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/plain')
      expect(response.body).to eq(StandardSite.publication_uri(did))
    end

    it 'is a 404 before the blog has ever synced' do
      blog.update_columns(standard_site_did: nil)

      get '/.well-known/site.standard.publication'

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'the link rel tags' do
    let(:entry) do
      create(:entry, :published, :with_photo, blog: blog, user: user).tap do |e|
        e.photos.each { |p| attach_image_to_photo(p) }
      end
    end

    def get_entry = get entry_long_path(entry.id, entry.slug)

    def noindex_count = response.body.scan('name="robots" content="noindex"').length

    it 'points a published, indexable entry at its document record' do
      get_entry

      expect(response.body).to include(%(rel="site.standard.publication"))
      expect(response.body).to include(
        %(rel="site.standard.document" href="at://#{did}/site.standard.document/#{StandardSite.document_rkey(entry.id)}")
      )
    end

    # ⚠️ The two must never both appear. A page telling crawlers not to index it while pointing at
    # a machine-readable copy of itself is saying two different things about the same entry.
    #
    # The count, rather than a plain include: _meta_tags emits a blog-level noindex outside
    # production, so a bare assertion here would pass in test whatever the entry head did.
    it 'says noindex, and names no document, for an entry hidden from search engines' do
      get_entry
      visible = noindex_count

      entry.update_columns(hide_from_search_engines: true)
      get_entry

      expect(noindex_count).to eq(visible + 1)
      expect(response.body).not_to include('rel="site.standard.document"')
    end

    it 'names no document when the blog has never synced' do
      blog.update_columns(standard_site_did: nil)

      get_entry

      expect(response.body).not_to include('rel="site.standard.document"')
      expect(response.body).not_to include('rel="site.standard.publication"')
    end
  end
end
