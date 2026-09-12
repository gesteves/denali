require 'rails_helper'

RSpec.describe StandardSite do
  let(:did) { 'did:plc:abc123' }
  let(:social_account) do
    create(:social_account, provider: 'bluesky', handle: 'me.bsky.social',
                            access_token: 'app-password', server_url: 'https://bsky.social')
  end
  let(:blog) do
    create(:blog, name: 'A Photoblog', meta_description: 'Pictures of things.',
                  standard_site_social_account: social_account, standard_site_did: did)
  end
  let(:user) { create(:user) }
  let(:service) { described_class.from_blog(blog.reload) }
  let(:entry) do
    create(:entry, :published, blog: blog, user: user, title: 'A Title', body: 'The **body** text.')
  end

  def stub_session
    stub_request(:post, 'https://bsky.social/xrpc/com.atproto.server.createSession')
      .to_return(status: 200, body: { did: did, accessJwt: 'jwt' }.to_json,
                 headers: { 'Content-Type' => 'application/json' })
  end

  def stub_put_record
    stub_request(:post, 'https://bsky.social/xrpc/com.atproto.repo.putRecord')
      .to_return(status: 200, body: { uri: 'at://x/y/z', cid: 'bafy' }.to_json,
                 headers: { 'Content-Type' => 'application/json' })
  end

  def stub_delete_record
    stub_request(:post, 'https://bsky.social/xrpc/com.atproto.repo.deleteRecord')
      .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })
  end

  before { stub_session }

  describe '.tid' do
    it 'is a 13-character TID' do
      expect(described_class.tid('anything')).to match(/\A[234567a-z]{13}\z/)
    end

    it 'is stable for one seed and different for another' do
      expect(described_class.tid('42')).to eq(described_class.tid('42'))
      expect(described_class.tid('42')).not_to eq(described_class.tid('43'))
    end

    # ⚠️ A content-addressed key is indistinguishable from a time-ordered one: the digest is masked
    # to 63 bits, so its high bit is zero and Bluesky.tid_time happily decodes it to a Time that
    # means nothing. Nothing passes a key from here to .record_timestamp, and nothing should,
    # because no check could catch it.
    it 'is indistinguishable from a time-ordered key' do
      expect(Bluesky.tid_time(described_class.tid('42'))).to be_a(Time)
    end
  end

  describe 'the publication record key' do
    # The lexicons need a TID for a record key, so the literal 'self' is not one. Addressing a
    # record by something that isn't a TID deletes a key that was never there and reports success.
    it 'is a TID, not the literal "self"' do
      expect(described_class::PUBLICATION_RKEY).to match(/\A[234567a-z]{13}\z/)
      expect(described_class::PUBLICATION_RKEY).not_to eq('self')
    end

    it 'builds the publication URI from it' do
      expect(described_class.publication_uri(did))
        .to eq("at://#{did}/site.standard.publication/#{described_class::PUBLICATION_RKEY}")
    end

    it 'has no URI without a DID' do
      expect(described_class.publication_uri(nil)).to be_nil
    end
  end

  describe '.from_blog' do
    it 'builds a client for a blog that names a usable Bluesky account' do
      expect(service).to be_a(described_class)
    end

    it 'is nil for a blog that names none' do
      blog.update_columns(standard_site_social_account_id: nil)
      expect(described_class.from_blog(blog.reload)).to be_nil
    end

    it 'is nil for an account of another provider' do
      social_account.update_columns(provider: 'mastodon')
      expect(described_class.from_blog(blog.reload)).to be_nil
    end
  end

  describe '#build_document_record' do
    subject(:record) { service.build_document_record(entry) }

    it 'names the lexicon and points at the publication' do
      expect(record['$type']).to eq('site.standard.document')
      expect(record['site']).to eq(described_class.publication_uri(did))
    end

    it 'carries the title, the path and an RFC3339 timestamp' do
      expect(record['title']).to eq('A Title')
      expect(record['path']).to eq(entry.permalink_path)
      expect(record['publishedAt']).to match(/\A\d{4}-\d{2}-\d{2}T[\d:.]+Z\z/)
    end

    it 'strips markdown out of the text content' do
      expect(record['textContent']).to eq('The body text.')
    end

    it 'cuts a tag to the limit of the lexicon and drops one that is empty' do
      allow(entry).to receive(:tag_list).and_return(['é' * 140, '  ', 'landscape'])

      tags = service.build_document_record(entry)['tags']

      expect(tags.length).to eq(2)
      expect(tags.first.scan(/\X/).length).to eq(described_class::MAX_TAG_GRAPHEMES)
      expect(tags.last).to eq('landscape')
    end

    it 'omits the cover image when no blob is supplied' do
      expect(record).not_to have_key('coverImage')
    end

    it 'includes the cover image when one is' do
      expect(service.build_document_record(entry, cover_image: { 'ref' => 'x' })['coverImage'])
        .to eq({ 'ref' => 'x' })
    end
  end

  describe '#build_publication_record' do
    subject(:record) { service.build_publication_record }

    it 'names the lexicon and carries the site' do
      expect(record['$type']).to eq('site.standard.publication')
      expect(record['name']).to eq('A Photoblog')
      expect(record['description']).to eq('Pictures of things.')
      expect(record['url']).not_to end_with('/')
    end

    it 'carries a basic theme with all four colours' do
      expect(record['basicTheme'].keys)
        .to contain_exactly('$type', 'background', 'foreground', 'accent', 'accentForeground')
    end

    # A blog that hides itself from search engines doesn't want a discovery feed either.
    it 'turns off discovery for a blog hidden from search engines' do
      expect(record['preferences']).to eq('showInDiscover' => true)

      blog.update_columns(hide_from_search_engines: true)
      expect(described_class.from_blog(blog.reload).build_publication_record['preferences'])
        .to eq('showInDiscover' => false)
    end
  end

  describe '#publishable?' do
    it 'is true for a published entry search engines may index' do
      expect(service.publishable?(entry)).to be true
    end

    # ⚠️ The headline rule. A hidden entry says noindex on its own page, so a machine-readable copy
    # of that page must not exist on the PDS either.
    it 'is false for a published entry hidden from search engines' do
      entry.update_columns(hide_from_search_engines: true)
      expect(service.publishable?(entry.reload)).to be false
    end

    it 'is false for a draft and for a queued entry' do
      expect(service.publishable?(build(:entry, status: 'draft'))).to be false
      expect(service.publishable?(build(:entry, status: 'queued'))).to be false
    end
  end

  describe '#sync_document' do
    before { stub_put_record }

    it 'writes the record and remembers its fingerprint' do
      expect(service.sync_document(entry.id)).to eq(:synced)
      expect(entry.reload.standard_site_fingerprint).to be_present
    end

    it 'addresses the record by its TID rkey, never the raw entry id' do
      service.sync_document(entry.id)

      expect(a_request(:post, 'https://bsky.social/xrpc/com.atproto.repo.putRecord')
        .with { |req| JSON.parse(req.body)['rkey'] == described_class.document_rkey(entry.id) })
        .to have_been_made
    end

    # The PDS doesn't know the site.standard.* lexicons, so its own check would refuse the record.
    it 'tells the PDS not to validate a lexicon it does not know' do
      service.sync_document(entry.id)

      expect(a_request(:post, 'https://bsky.social/xrpc/com.atproto.repo.putRecord')
        .with { |req| JSON.parse(req.body)['validate'] == false }).to have_been_made
    end

    it 'writes nothing the second time when nothing changed' do
      service.sync_document(entry.id)
      expect(described_class.from_blog(blog.reload).sync_document(entry.id)).to eq(:unchanged)

      expect(a_request(:post, 'https://bsky.social/xrpc/com.atproto.repo.putRecord'))
        .to have_been_made.once
    end

    it 'writes again when the entry changed' do
      service.sync_document(entry.id)
      entry.update!(title: 'Another Title')

      expect(described_class.from_blog(blog.reload).sync_document(entry.id)).to eq(:synced)
    end

    # ⚠️ The whole point of this change: flipping the setting has to unpublish the record, not wait
    # for a backfill.
    it 'deletes the record when the entry is hidden from search engines' do
      stub_delete_record
      service.sync_document(entry.id)
      entry.update_columns(hide_from_search_engines: true)

      expect(described_class.from_blog(blog.reload).sync_document(entry.id)).to eq(:deleted)
      expect(a_request(:post, 'https://bsky.social/xrpc/com.atproto.repo.deleteRecord'))
        .to have_been_made
      expect(entry.reload.standard_site_fingerprint).to be_nil
    end

    it 'writes it again when the entry is shown to search engines once more' do
      stub_delete_record
      entry.update_columns(hide_from_search_engines: true)
      service.sync_document(entry.id)
      entry.update_columns(hide_from_search_engines: false)

      expect(described_class.from_blog(blog.reload).sync_document(entry.id)).to eq(:synced)
    end

    it 'deletes the record when the entry is unpublished' do
      stub_delete_record
      entry.update_columns(status: 'draft')

      expect(service.sync_document(entry.id)).to eq(:deleted)
    end

    it 'deletes the record for an entry that is gone' do
      stub_delete_record
      expect(service.sync_document(entry.id + 9999)).to eq(:deleted)
    end

    # ⚠️ Clearing the fingerprint after a failed delete would leave the record on the PDS with
    # nothing able to tell the difference, and the job would return as though it had worked.
    it 'raises and keeps the fingerprint when the PDS refuses the delete' do
      service.sync_document(entry.id)
      fingerprint = entry.reload.standard_site_fingerprint
      stub_request(:post, 'https://bsky.social/xrpc/com.atproto.repo.deleteRecord')
        .to_return(status: 500, body: 'nope')
      entry.update_columns(hide_from_search_engines: true)

      expect { described_class.from_blog(blog.reload).sync_document(entry.id) }
        .to raise_error(/Could not delete/)
      expect(entry.reload.standard_site_fingerprint).to eq(fingerprint)
    end
  end

  # ⚠️ A 429 is "come back later", not "this failed". Without the typed error a write would retry on
  # the default backoff and spend attempts against a limit that hasn't lifted, and a delete would
  # report a failure the caller could do nothing about.
  describe 'when the PDS is rate limiting us' do
    let(:reset) { 5.minutes.from_now.to_i }

    it 'raises an error carrying how long to wait' do
      stub_request(:post, 'https://bsky.social/xrpc/com.atproto.repo.putRecord')
        .to_return(status: 429, body: 'slow down', headers: { 'ratelimit-reset' => reset.to_s })

      expect { service.sync_document(entry.id) }
        .to raise_error(AtProto::RateLimitedError) { |e| expect(e.retry_after).to be_within(5).of(300) }
    end

    it 'waits a sane amount when the header is missing or nonsense' do
      stub_request(:post, 'https://bsky.social/xrpc/com.atproto.repo.putRecord')
        .to_return(status: 429, body: 'slow down')

      expect { service.sync_document(entry.id) }
        .to raise_error(AtProto::RateLimitedError) { |e| expect(e.retry_after).to eq(60) }
    end

    it 'raises rather than reporting a delete that simply failed' do
      stub_request(:post, 'https://bsky.social/xrpc/com.atproto.repo.deleteRecord')
        .to_return(status: 429, body: 'slow down', headers: { 'ratelimit-reset' => reset.to_s })
      entry.update_columns(status: 'draft')

      expect { service.sync_document(entry.id) }.to raise_error(AtProto::RateLimitedError)
    end
  end

  # ⚠️ A photo's width and height live in its blob metadata and an asynchronous job fills them in,
  # so a freshly published entry has neither for a moment. facebook_card_url works a crop out of
  # them and raises NoMethodError without them, and that call sits inside #document_fingerprint,
  # which runs before anything that could rescue it. The job backed off 25 times on a NoMethodError.
  describe 'an entry whose cover photo has not been analysed yet' do
    let(:entry) do
      create(:entry, :published, :with_photo, blog: blog, user: user, title: 'A Title')
    end

    before { stub_put_record }

    it 'has no dimensions to crop with' do
      expect(entry.photos.first.has_dimensions?).to be false
    end

    it 'builds the record without raising, and without a cover image' do
      record = service.build_document_record(entry, cover_image: service.send(:cover_source, service.cover_image_url(entry)))

      expect(record['title']).to eq('A Title')
      expect(record).not_to have_key('coverImage')
    end

    it 'syncs rather than dying on a NoMethodError' do
      expect(service.sync_document(entry.id)).to eq(:synced)
    end
  end

  describe '#sync_publication' do
    before { stub_put_record }

    it 'writes the record and remembers the DID and the fingerprint' do
      blog.update_columns(standard_site_did: nil, standard_site_fingerprint: nil)

      expect(described_class.from_blog(blog.reload).sync_publication).to eq(:synced)
      expect(blog.reload.standard_site_did).to eq(did)
      expect(blog.standard_site_fingerprint).to be_present
    end

    it 'writes nothing the second time when nothing changed' do
      service.sync_publication
      expect(described_class.from_blog(blog.reload).sync_publication).to eq(:unchanged)

      expect(a_request(:post, 'https://bsky.social/xrpc/com.atproto.repo.putRecord'))
        .to have_been_made.once
    end
  end

  # ⚠️ A backfill is thousands of jobs draining over hours. Without these lines there is no way to
  # tell a run that is working from one that is quietly doing nothing.
  describe 'logging' do
    before { stub_put_record }

    it 'names the record it wrote' do
      expect(Rails.logger).to receive(:info).with(/document #{entry.id} synced as #{described_class.document_rkey(entry.id)}/)

      service.sync_document(entry.id)
    end

    it 'says so when it skipped a record that had not changed' do
      service.sync_document(entry.id)
      expect(Rails.logger).to receive(:info).with(/document #{entry.id} unchanged/)

      described_class.from_blog(blog.reload).sync_document(entry.id)
    end

    it 'names the record it deleted' do
      stub_delete_record
      entry.update_columns(status: 'draft')
      expect(Rails.logger).to receive(:info).with(/document .* deleted/)

      service.sync_document(entry.id)
    end
  end

  describe '#backfill' do
    let(:hidden) { create(:entry, :published, blog: blog, user: user, hide_from_search_engines: true) }
    let(:draft) { create(:entry, blog: blog, user: user) }

    def stub_list(rkeys)
      stub_request(:get, /com\.atproto\.repo\.listRecords/)
        .to_return(status: 200,
                   body: { records: rkeys.map { |k| { uri: "at://#{did}/site.standard.document/#{k}" } } }.to_json,
                   headers: { 'Content-Type' => 'application/json' })
    end

    def stub_own_publication(url)
      stub_request(:get, /com\.atproto\.repo\.getRecord/)
        .to_return(status: 200, body: { value: { url: url } }.to_json,
                   headers: { 'Content-Type' => 'application/json' })
    end

    before do
      stub_put_record
      stub_delete_record
      entry
      hidden
      draft
    end

    it 'queues a sync for each indexable entry and prunes the rest' do
      stub_own_publication(Rails.application.routes.url_helpers.root_url)
      stub_list([described_class.document_rkey(entry.id), described_class.document_rkey(hidden.id)])

      result = service.backfill

      expect(result[:synced]).to eq(1)
      expect(result[:pruned]).to eq(1)
      expect(StandardSiteJob).to have_enqueued_sidekiq_job('sync_document', entry.id)
    end

    # ⚠️ A PDS budgets writes per account: 3 points for a create against 5,000 an hour, so at most
    # 1,666 records an hour. Sidekiq runs ten of these at a time, so queueing them all at once
    # would hit the ceiling within minutes of a backfill of any size.
    it 'spaces the syncs out to stay inside the write budget' do
      stub_own_publication(Rails.application.routes.url_helpers.root_url)
      stub_list([])
      more = Array.new(3) { create(:entry, :published, blog: blog, user: user) }
      StandardSiteJob.jobs.clear

      service.backfill

      queued_at = StandardSiteJob.jobs.map { |job| job['at'] }.compact.sort
      expect(queued_at.length).to eq(more.length) # the first one goes out immediately
      expect((queued_at.last - queued_at.first).round)
        .to eq(((more.length - 1) * AtProto.seconds_between_writes).round)
    end

    it 'writes nothing on a dry run' do
      stub_list([])
      StandardSiteJob.jobs.clear

      expect(service.backfill(dry_run: true)).to include(dry_run: true, synced: 1)
      expect(service.backfill(dry_run: true)[:duration]).to be > 0
      expect(StandardSiteJob.jobs).to be_empty
      expect(a_request(:post, 'https://bsky.social/xrpc/com.atproto.repo.putRecord')).not_to have_been_made
    end

    # ⚠️ PUBLICATION_RKEY is tid('self'), so every installation writes its publication at the same
    # key. Two sites pointed at one account would delete each other's documents as orphans, and a
    # document carries no field naming the site that wrote it.
    # ⚠️ The check has to come BEFORE sync_publication, which stamps this site's own URL into the
    # publication record. A check after it reads back what we just wrote, so it can never fail —
    # and by then the other site's publication is already overwritten.
    it 'stops before writing anything when the repo belongs to another site' do
      stub_own_publication('https://someone-else.example')
      stub_list(['3446ygrm3x4bk'])
      StandardSiteJob.jobs.clear

      expect { service.backfill }.to raise_error(/names another site/)

      expect(a_request(:post, 'https://bsky.social/xrpc/com.atproto.repo.putRecord')).not_to have_been_made
      expect(a_request(:post, 'https://bsky.social/xrpc/com.atproto.repo.deleteRecord')).not_to have_been_made
      expect(StandardSiteJob.jobs).to be_empty
    end
  end
end
