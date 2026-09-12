require 'digest'

# Publishes the blog to the AT Protocol as standard.site records, in the same PDS repo the blog's
# Bluesky account already uses:
#
#   - one site.standard.publication record for the site,
#   - one site.standard.document record for every entry that search engines are allowed to index,
#   - the record goes away when an entry is unpublished, hidden from search engines, or deleted.
#
# ⚠️ Hiding an entry from search engines unpublishes it here too. A standard.site document is a
# machine-readable copy of the page for any reader that wants one, so publishing one for a page
# that carries `<meta name="robots" content="noindex">` would say two different things about the
# same entry. Entry.indexable_in_search_engines is the single predicate, and the sitemap uses it
# too.
#
# Each record carries a SHA-256 fingerprint of its own content, so the slow part — a cover-image
# upload and a putRecord — only runs when something actually changed.
#
# @see https://standard.site
class StandardSite
  include AtProto

  PUBLICATION_COLLECTION = 'site.standard.publication'.freeze
  DOCUMENT_COLLECTION = 'site.standard.document'.freeze

  # The largest blob either lexicon takes for an icon or a cover image: it has to be under 1MB.
  #
  # ⚠️ This is not Bluesky::MAX_BLOB_SIZE, which is 2MB. The two limits belong to two different
  # lexicons and they differ on purpose — don't align them.
  MAX_BLOB_SIZE = 1_000_000

  # Aim under the hard limit so a recompression doesn't land right on the edge.
  BLOB_SIZE_TARGET = 950_000

  # The text limits of the two lexicons, in grapheme clusters. A field past one of them makes the
  # whole record invalid, so one long tag would take the document down with it.
  MAX_NAME_GRAPHEMES = 500
  MAX_DESCRIPTION_GRAPHEMES = 3_000
  MAX_TAG_GRAPHEMES = 128

  # The theme, for readers that render the site's content in their own interface.
  #
  # ⚠️ This is a copy of the light-mode tokens in app/assets/stylesheets. The lexicon has no
  # dark-mode equivalent, and nothing checks that the two still agree.
  BASIC_THEME = {
    '$type' => 'site.standard.theme.basic',
    'background' => { '$type' => 'site.standard.theme.color#rgb', 'r' => 255, 'g' => 255, 'b' => 255 },
    'foreground' => { '$type' => 'site.standard.theme.color#rgb', 'r' => 68, 'g' => 68, 'b' => 68 },
    'accent' => { '$type' => 'site.standard.theme.color#rgb', 'r' => 191, 'g' => 2, 'b' => 34 },
    'accentForeground' => { '$type' => 'site.standard.theme.color#rgb', 'r' => 255, 'g' => 255, 'b' => 255 }
  }.freeze

  # Makes a stable TID from a seed: the low 63 bits of its SHA-256 digest, in base32.
  #
  # ⚠️ This is content-addressed and deliberately not time-ordered. The same entry has to give the
  # same record key every time, or a sync would add a second record instead of replacing the first
  # and a delete would miss. AtProto.new_tid is the time-ordered one, for a record with no natural
  # key of its own.
  #
  # ⚠️ The lexicons need a TID for a record key, so an entry id can't be one directly. Addressing a
  # record by a raw id deletes a key that was never there and reports success, leaving the real
  # record on the PDS until the next backfill finds it.
  #
  # @param seed [String] the natural key.
  # @return [String] a 13-character TID.
  def self.tid(seed)
    encode_tid(Digest::SHA256.hexdigest(seed.to_s).to_i(16) & ((1 << 63) - 1))
  end

  # The publication is the repo's singleton, at a stable TID made from the "self" seed.
  PUBLICATION_RKEY = tid('self')

  # The document record key of an entry. It comes from the id alone, so a sync, a delete and a
  # prune all work out the same key, and a delete needs no entry row at all.
  #
  # @param entry_id [Integer, String] the entry's id.
  # @return [String] a 13-character TID.
  def self.document_rkey(entry_id)
    tid(entry_id.to_s)
  end

  # The at:// URI of a blog's publication record. This is the only place that format is written.
  #
  # @param did [String] the repo's DID.
  # @return [String, nil] the URI, or nil without a DID.
  def self.publication_uri(did)
    return if did.blank?

    "at://#{did}/#{PUBLICATION_COLLECTION}/#{PUBLICATION_RKEY}"
  end

  # Builds a client for a blog, from the Bluesky account the blog names.
  #
  # @param blog [Blog] the blog to publish.
  # @return [StandardSite, nil] nil when the blog names no usable account.
  def self.from_blog(blog)
    account = blog&.standard_site_account
    return if account.nil?

    new(blog: blog, social_account: account)
  end

  # @param blog [Blog] the blog to publish.
  # @param social_account [SocialAccount] the Bluesky account whose repo holds the records.
  def initialize(blog:, social_account:)
    @blog = blog
    configure_at_proto(base_url: social_account.server_url,
                       identifier: social_account.handle,
                       password: social_account.access_token)
  end

  # Names this client in the messages AtProto raises.
  #
  # @return [String]
  def at_proto_label = 'standard.site'

  # Publishes or removes the document record of an entry.
  #
  # It reloads the entry rather than trusting what the caller knew, so one job argument covers a
  # publish, an unpublish and a change to the search-engine setting in either direction. An entry
  # that is gone, a draft, queued, or hidden from search engines takes the delete path.
  #
  # @param entry_id [Integer] the entry's id.
  # @return [Symbol] :synced, :unchanged, :deleted or :skipped.
  def sync_document(entry_id)
    entry = @blog.entries.find_by(id: entry_id)

    if entry.nil? || !publishable?(entry)
      return remove_document!(self.class.document_rkey(entry_id), entry)
    end

    do_sync_document(entry)
  end

  # Removes the document record of an entry that is gone.
  #
  # @param entry_id [Integer] the entry's id.
  # @return [Symbol] :deleted.
  def delete_document(entry_id)
    remove_document!(self.class.document_rkey(entry_id), @blog.entries.find_by(id: entry_id))
  end

  # Publishes the publication record from the blog's current settings.
  #
  # @return [Symbol] :synced or :unchanged.
  def sync_publication
    record = build_publication_record(icon: cover_source(publication_icon_url))
    fingerprint = fingerprint_of(record)
    return :unchanged if fingerprint == @blog.standard_site_fingerprint

    record = build_publication_record(icon: upload_image(publication_icon_url))
    put_record(collection: PUBLICATION_COLLECTION, rkey: PUBLICATION_RKEY, record: record,
               validate: false)
    @blog.update_columns(standard_site_did: did, standard_site_fingerprint: fingerprint)
    :synced
  end

  # Makes the repo agree with the blog: it publishes the publication, queues a sync for every entry
  # search engines may index, then deletes whatever documents are left over.
  #
  # ⚠️ The syncs are scheduled, not queued all at once. A PDS budgets writes per account — 3 points
  # for a create against 5,000 an hour — so at most 1,666 records an hour. Sidekiq runs ten jobs at
  # a time here, so a backfill of a few hundred entries would hit that in minutes and every job
  # past it would get a 429 and start backing off. Spreading them costs wall-clock time on a job
  # that runs once, and buys a run that doesn't fight the limit at all.
  #
  # A prune is a delete, which is 1 point, and it happens inline: a prune set is normally a handful
  # of records, and the rate-limit error is raised rather than swallowed if it ever isn't.
  #
  # @param dry_run [Boolean] when true, report what would happen and write nothing.
  # @return [Hash] counts, the spacing, and how long the run will take, for the rake task to print.
  def backfill(dry_run: false)
    current = @blog.entries.indexable_in_search_engines.pluck(:id)
    current_rkeys = current.map { |id| self.class.document_rkey(id) }
    stale = list_record_rkeys(collection: DOCUMENT_COLLECTION) - current_rkeys
    spacing = AtProto.seconds_between_writes
    report = { synced: current.size, pruned: stale.size, spacing: spacing,
               duration: (current.size * spacing).seconds }

    return report.merge(dry_run: true) if dry_run

    sync_publication
    unless own_repo?
      raise "The publication in this repo names another site. Refusing to prune #{stale.size} record(s)."
    end

    current.each_with_index do |id, index|
      StandardSiteJob.perform_in((index * spacing).seconds, 'sync_document', id)
    end
    pruned = stale.count { |rkey| delete_record(collection: DOCUMENT_COLLECTION, rkey: rkey) }
    report.merge(pruned: pruned, dry_run: false)
  end

  # The DID of the repo, refreshing the blog's copy of it.
  #
  # @return [String] the DID.
  def store_did!
    value = did
    @blog.update_columns(standard_site_did: value) if value.present? && value != @blog.standard_site_did
    value
  end

  # Whether an entry should have a document record.
  #
  # ⚠️ The same rule as Entry.indexable_in_search_engines, which the sitemap uses. An entry that
  # says noindex on its own page must not be published here.
  #
  # @param entry [Entry] the entry.
  # @return [Boolean]
  def publishable?(entry)
    entry.is_published? && !entry.hide_from_search_engines?
  end

  # Builds a site.standard.publication record.
  #
  # The caller supplies the icon, so the record can be built for a fingerprint without a network
  # request.
  #
  # @param icon [Hash, String, nil] the uploaded blob, or a source descriptor for a fingerprint.
  # @return [Hash] the record.
  def build_publication_record(icon: nil)
    record = {
      '$type' => PUBLICATION_COLLECTION,
      'url' => publication_url,
      'name' => truncate_graphemes(@blog.name.to_s, MAX_NAME_GRAPHEMES),
      'basicTheme' => BASIC_THEME,
      # A blog that hides itself from search engines doesn't want a discovery feed either.
      'preferences' => { 'showInDiscover' => !@blog.hide_from_search_engines? }
    }

    description = plain_text(@blog.meta_description.presence || @blog.about)
    record['description'] = truncate_graphemes(description, MAX_DESCRIPTION_GRAPHEMES) if description.present?
    record['icon'] = icon if icon.present?
    record
  end

  # Builds a site.standard.document record.
  #
  # @param entry [Entry] the entry.
  # @param cover_image [Hash, String, nil] the uploaded blob, or a source descriptor.
  # @return [Hash] the record.
  def build_document_record(entry, cover_image: nil)
    record = {
      '$type' => DOCUMENT_COLLECTION,
      'site' => self.class.publication_uri(@blog.standard_site_did.presence || did),
      'title' => truncate_graphemes(entry.plain_title.to_s, MAX_NAME_GRAPHEMES),
      'publishedAt' => iso8601(entry.published_at),
      'path' => entry.permalink_path
    }

    # modified_at, not updated_at: the photo jobs touch an entry row long after anything a reader
    # would call an edit, and modified_at is what the sitemap reports as lastmod.
    updated = iso8601(entry.modified_at)
    record['updatedAt'] = updated if updated.present?

    description = plain_text(entry.meta_description(entry.photos.first))
    record['description'] = truncate_graphemes(description, MAX_DESCRIPTION_GRAPHEMES) if description.present?

    text = plain_text(entry.body)
    record['textContent'] = text if text.present?

    tags = Array(entry.tag_list).map { |tag| truncate_graphemes(tag.to_s, MAX_TAG_GRAPHEMES) }.compact_blank
    record['tags'] = tags if tags.present?

    record['coverImage'] = cover_image if cover_image.present?
    record
  end

  # The content fingerprint of an entry's record, with the cover image's source URL standing in for
  # the blob. A different photo changes the URL, so it changes the fingerprint without a request.
  #
  # @param entry [Entry] the entry.
  # @return [String] a SHA-256 hex digest.
  def document_fingerprint(entry)
    fingerprint_of(build_document_record(entry, cover_image: cover_source(cover_image_url(entry))))
  end

  # The URL of an entry's cover image, if it has one that can be addressed yet.
  #
  # ⚠️ The dimensions guard is not optional. A photo's width and height live in its blob metadata
  # and an asynchronous job fills them in, so a freshly published entry has neither for a moment.
  # #facebook_card_url works out a crop from them and raises NoMethodError without them — and this
  # is reached through #document_fingerprint, which runs before anything that could rescue it.
  #
  # It returns nil rather than raising, so a photo that never gets analysed costs the record its
  # picture and not its existence. StandardSiteJob backs off for the ordinary case, where the
  # dimensions are seconds away.
  #
  # @param entry [Entry] the entry.
  # @return [String, nil]
  def cover_image_url(entry)
    photo = entry.photos.first
    return unless photo&.has_dimensions?

    photo.facebook_card_url
  end

  private

  # Whether this repo's publication record names this site.
  #
  # ⚠️ PUBLICATION_RKEY is tid('self'), so every installation of this code writes its publication at
  # the same record key. Two sites pointed at one account overwrite each other's publication and
  # then delete each other's documents as orphans, and a document carries no field naming the site
  # that wrote it, so nothing could sort them out afterwards.
  #
  # True for a repo that has no publication record yet, which is a first run.
  #
  # @return [Boolean]
  def own_repo?
    record = get_own_record(collection: PUBLICATION_COLLECTION, rkey: PUBLICATION_RKEY)
    stored = record&.dig('url').to_s.chomp('/')
    stored.blank? || stored == publication_url
  end

  # Publishes one document record, skipping the upload and the write when nothing changed.
  #
  # @param entry [Entry] the entry.
  # @return [Symbol] :synced or :unchanged.
  def do_sync_document(entry)
    fingerprint = document_fingerprint(entry)
    return :unchanged if fingerprint == entry.standard_site_fingerprint

    store_did!
    record = build_document_record(entry, cover_image: upload_image(cover_image_url(entry)))
    put_record(collection: DOCUMENT_COLLECTION, rkey: self.class.document_rkey(entry.id),
               record: record, validate: false)
    entry.update_columns(standard_site_fingerprint: fingerprint)
    :synced
  end

  # Deletes a document record and forgets its fingerprint.
  #
  # ⚠️ The fingerprint is only cleared after the PDS accepted the delete. Clearing it after a failed
  # one would leave the record on the PDS with nothing able to tell the difference, and the job
  # would return as though it had worked.
  #
  # @param rkey [String] the record key.
  # @param entry [Entry, nil] the entry, when its row still exists.
  # @return [Symbol] :deleted.
  # @raise [RuntimeError] if the PDS refused the delete, so Sidekiq tries again.
  def remove_document!(rkey, entry)
    unless delete_record(collection: DOCUMENT_COLLECTION, rkey: rkey)
      raise "Could not delete #{DOCUMENT_COLLECTION}/#{rkey} from the PDS"
    end

    entry&.update_columns(standard_site_fingerprint: nil)
    :deleted
  end

  # Downloads an image, brings it under the blob limit and uploads it.
  #
  # It fails soft: a record with no picture is much better than no record at all, and an upload is
  # the one step here that depends on a host we don't control.
  #
  # @param url [String, nil] the image URL.
  # @return [Hash, nil] the blob, or nil.
  def upload_image(url)
    return if url.blank?

    data, content_type = fetch_image(url)
    # The photo CDN takes a size in pixels and promises nothing in bytes, so a picture with a lot
    # of detail comes back over the limit. Without this the PDS refuses the record and the job
    # retries all day for a reason that can never change.
    if data.bytesize > MAX_BLOB_SIZE
      data = compress_under_blob_limit(data, target: BLOB_SIZE_TARGET)
      content_type = 'image/jpeg'
    end
    return if data.bytesize > MAX_BLOB_SIZE

    upload_blob(data, content_type)['blob']
  rescue StandardError => e
    Rails.logger.warn("standard.site: could not upload #{url}: #{e.message}")
    nil
  end

  # A stable descriptor of an image's source, standing in for a blob inside a fingerprint.
  #
  # @param url [String, nil] the image URL.
  # @return [String, nil]
  def cover_source(url)
    url.presence
  end

  # The icon of the publication. The touch icon is square, which is what the lexicon asks for; the
  # logo is a fallback and is usually not.
  #
  # @return [String, nil]
  def publication_icon_url
    if @blog.touch_icon.attached?
      @blog.touch_icon_url(width: 512, height: 512)
    elsif @blog.logo.attached?
      @blog.logo_url(width: 512)
    end
  end

  # @return [String] the site's root, with no trailing slash.
  def publication_url
    root_url.chomp('/')
  end

  # @return [String] the site's root URL.
  def root_url
    Rails.application.routes.url_helpers.root_url
  end

  # @param record [Hash] the record.
  # @return [String] a SHA-256 hex digest of it.
  def fingerprint_of(record)
    Digest::SHA256.hexdigest(record.to_json)
  end

  # Markdown into plain text: no markup, decoded entities, one space between words.
  #
  # ⚠️ Deliberately not Formattable#markdown_to_plaintext, which runs SmartyPants. This text goes
  # into a content fingerprint, so a change to the typography here would resync every record.
  #
  # @param text [String, nil] the Markdown.
  # @return [String, nil] the plain text, or nil when blank.
  def plain_text(text)
    return if text.blank?

    html = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new, autolink: true, no_intra_emphasis: true)
                              .render(text.to_s)
    HTMLEntities.new.decode(Sanitize.fragment(html)).gsub(/\s+/, ' ').strip.presence
  end

  # @param value [Time, String, nil] a timestamp.
  # @return [String, nil] it as a UTC RFC3339 string with milliseconds.
  def iso8601(value)
    return if value.blank?

    value.to_time.utc.iso8601(3)
  rescue StandardError
    nil
  end
end
