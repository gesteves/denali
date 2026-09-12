require 'mini_magick'

class Bluesky
  MAX_POST_LENGTH = 300

  # app.bsky.feed.post#text is capped in graphemes *and* in bytes. 300 family emoji is 300
  # graphemes but about 7,500 bytes, and the PDS rejects that record, so counting graphemes alone
  # lets through a post that can never be created — and the job then retries it forever.
  MAX_POST_BYTES = 3_000

  MAX_PHOTOS = 4

  # app.bsky.richtext.facet#tag limits. A tag past either one makes the whole record invalid, so an
  # over-long hashtag would take the post down with it.
  MAX_TAG_GRAPHEMES = 64
  MAX_TAG_BYTES = 640

  # Bluesky rejects any post embed whose image blob exceeds this many bytes,
  # reported as "blob too big" at $.record.embed.images[].image when the record
  # is created (uploadBlob itself accepts it, so the failure surfaces later).
  MAX_BLOB_SIZE = 2_000_000

  # When we have to recompress an oversized image, aim comfortably under the hard
  # limit so we don't land right on the edge.
  BLOB_SIZE_TARGET = 1_950_000

  # Cloudflare has no equivalent to Thumbor's old max_bytes filter, so a
  # transformed JPEG can still come back over the limit. When it does, walk it
  # down these steps — dropping JPEG quality first, then scaling the image — and
  # upload the first result that fits. Without this, an oversized photo produces
  # the same too-big blob on every retry and can never be shared.
  BLOB_COMPRESSION_STEPS = [
    { quality: 70 },
    { quality: 60 },
    { quality: 50 },
    { quality: 40, resize: '85%' },
    { quality: 40, resize: '70%' },
    { quality: 40, resize: '55%' }
  ].freeze

  # Who's allowed to reply to a post. Only followers and people the account follows,
  # to keep drive-by replies from the popular feeds out of the thread.
  THREADGATE_ALLOW_RULES = [
    { "$type" => "app.bsky.feed.threadgate#followerRule" },
    { "$type" => "app.bsky.feed.threadgate#followingRule" }
  ].freeze

  # A bare URL. It stops before a trailing period or bracket, which is nearly always punctuation of
  # the sentence rather than part of the address.
  #
  # This is the source of truth for "what is an address": SocialText and Typography both read it,
  # so a string that gets a link facet here is treated as a URL everywhere else too.
  URL_PATTERN = %r{(?:^|[$|\W])(https?://[a-zA-Z0-9\-._~:/?\#\[\]@!$&'()*+,;%=]*[a-zA-Z0-9\-_~/\#@$&*+=])}

  # An @handle, from the sample in the AT Protocol documentation.
  MENTION_PATTERN = /(?:^|[$|\W])(@(?:[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)/

  # Zero-width and formatting characters a hashtag can't contain, from the Bluesky client's own tag
  # rule.
  TAG_EXCLUDED = "\u00AD\u2060\u200A\u200B\u200C\u200D\u20E2".freeze

  # A #hashtag, ported from the Bluesky client so a facet covers exactly what a reader sees tagged.
  #
  # It needs at least one character that is neither a digit nor punctuation, which is what keeps
  # "#1" a number rather than a tag. It starts at whitespace or the start of the text, as the
  # client does. And it deliberately avoids `\w`: Ruby's `\w` is ASCII-only, so "#café" would be
  # tagged "caf" with a facet highlighting only part of the word.
  TAG_PATTERN = /(?:^|\s)([#＃](?!\uFE0F)[^\s#{TAG_EXCLUDED}]*[^\d\s\p{P}#{TAG_EXCLUDED}]+[^\s#{TAG_EXCLUDED}]*)/

  TAG_PREFIX = /\A[#＃]/

  # The client trims trailing punctuation off a tag, so "#trail." tags "trail".
  TRAILING_PUNCTUATION = /\p{P}+\z/

  # Every request here gets a timeout. Admin::EntriesController runs a share inline, inside the web
  # request, so a PDS that hangs would otherwise hang Rails; in a job it would hold a Sidekiq
  # thread until the process was killed.
  SESSION_TIMEOUT = 10
  RESOLVE_TIMEOUT = 5
  REQUEST_TIMEOUT = 15
  UPLOAD_TIMEOUT = 30
  IMAGE_TIMEOUT = 15

  # The most we will read from the photo CDN before giving up. These are our own URLs, but a body
  # of unbounded size read into a Sidekiq thread is still a way to lose the process.
  MAX_SOURCE_IMAGE_BYTES = 20 * 1024 * 1024

  # The PDS rejected our token. The caller clears the cached session and tries once more.
  class UnauthorizedError < StandardError; end

  # Bluesky refused the handle and app password outright.
  class AuthenticationError < StandardError; end

  # The PDS could not be reached at all.
  class ConnectionError < StandardError; end

  # Creates a Bluesky instance from a SocialAccount.
  #
  # @param social_account [SocialAccount] the social account to use.
  # @return [Bluesky] a new Bluesky instance.
  def self.from_social_account(social_account)
    new(
      base_url: social_account.server_url,
      email: social_account.handle,
      password: social_account.access_token
    )
  end

  # Renders a post the way the record will hold it: typography applied, Markdown links reduced to
  # their words, and the position of each of those words recorded.
  #
  # The order is load-bearing. Typography runs first because MarkdownLinks produces the character
  # offsets that become facet byte offsets, so a `...` collapsed to `…` afterwards would shift
  # every facet after it.
  #
  # @param text [String, nil] the raw text of the post, with Markdown syntax in it.
  # @return [MarkdownLinks::Result] the plain text, and a Link for each link in it.
  def self.render(text)
    MarkdownLinks.parse(Typography.apply(text))
  end

  # @param text [String, nil] the raw text of the post, with Markdown syntax in it.
  # @return [String] the plain text the post will hold.
  def self.plain_text(text)
    render(text).text
  end

  # Returns the length of the post text in Unicode graphemes.
  #
  # This measures what the *record* will hold, so it renders first: the address of a link lives in
  # a facet rather than in the text, which makes `[my post](https://example.com)` 7 characters and
  # not 30. Counting the raw words would reject a post that Bluesky accepts.
  #
  # @param text [String, nil] the raw text of the post with Markdown syntax.
  # @return [Integer] the length in Unicode graphemes.
  def self.post_length(text)
    SocialText.graphemes(plain_text(text))
  end

  # Verifies that a post fits in one skeet: not empty, within 300 graphemes, and within the 3,000
  # bytes the lexicon also allows for. Both limits are real, and emoji-heavy text can pass the
  # first and fail the second.
  #
  # @param text [String] the raw text of the post with Markdown syntax.
  # @return [Boolean] true if the post can be created, false otherwise.
  def self.valid_post_length?(text)
    return false unless text.is_a?(String)

    plain = plain_text(text)
    length = SocialText.graphemes(plain)
    length.positive? && length <= MAX_POST_LENGTH && plain.bytesize <= MAX_POST_BYTES
  end

  # Every link in a post, in order, as character offsets into the plain text.
  #
  # A bare URL inside a Markdown link's words is not a second link. `[https://a](https://b)` would
  # otherwise get two facets over one range, which clients render as a broken link.
  #
  # @param text [String, nil] the plain text, as MarkdownLinks rendered it.
  # @param markdown [Array<MarkdownLinks::Link>] the links from that same parse.
  # @return [Array<MarkdownLinks::Link>] every link, sorted by where it starts.
  def self.link_ranges(text, markdown = [])
    text = text.to_s
    taken = markdown.map { |link| link.start...link.finish }
    bare = []

    SocialText.url_ranges(text).each do |range|
      next if taken.any? { |other| other.cover?(range.begin) }

      bare << MarkdownLinks::Link.new(start: range.begin, finish: range.end, url: text[range])
    end

    (markdown + bare).sort_by(&:start)
  end

  # Initializes a new instance of the Bluesky class.
  #
  # @param base_url [String] the base URL of the Bluesky API.
  # @param email [String] the email for the Bluesky account.
  # @param password [String] the single-app password for the Bluesky account.
  def initialize(base_url:, email:, password:)
    @base_url = base_url
    @auth = {
      identifier: email,
      password: password
    }
  end

  # Verifies that the text of a post is equal to or less than 300 Unicode graphemes.
  #
  # @param text [String] the raw text of the post with Markdown syntax.
  # @return [Boolean] true if the plain text is valid, false otherwise.
  def valid_post_length?(text)
    self.class.valid_post_length?(text)
  end

  # Returns the length of the post text in Unicode graphemes.
  #
  # @param text [String] the raw text of the post with Markdown syntax.
  # @return [Integer] the length in Unicode graphemes.
  def post_length(text)
    self.class.post_length(text)
  end

  # Skeets (sorry, Jay) with optional photos to Bluesky.
  #
  # @param text [String] the text of the post.
  # @param photos [Array<Hash>] an optional array of hashes representing photos.
  #   Each hash should include :url, :alt_text, :width, and :height.
  # @param in_reply_to [String, nil] the public URL of a post to reply to. Optional.
  # @return [Hash] the parsed response body if successful.
  # @raise [RuntimeError] if the post request fails.
  def skeet(text:, photos: [], in_reply_to: nil, quote: nil)
    # One parse gives both the text the record holds and the offsets its facets need. Rendering
    # twice would let the two disagree.
    post = self.class.render(text)

    # Construct the reply object for the post, if provided
    reply = construct_reply(in_reply_to)

    # Construct the embed object, if provided
    embed = construct_embed(photos, quote)

    # Construct the record data for the skeet
    record_data = {
      "$type" => "app.bsky.feed.post",
      text: post.text,
      langs: ["en-US"],
      createdAt: Time.now.iso8601
    }

    facets = build_facets(post.text, links: post.links)
    record_data[:facets] = facets if facets.any?
    record_data[:embed] = embed if embed.present?
    record_data[:reply] = reply if reply.present?

    record = {
      repo: did,
      collection: "app.bsky.feed.post",
      record: record_data
    }

    create_record(record)
  end

  # Opens a session and returns the account's DID, so the admin can check a handle and app password
  # before it stores them.
  #
  # @return [String] the DID of the authenticated account.
  # @raise [AuthenticationError] if Bluesky refuses the credentials.
  # @raise [ConnectionError] if the PDS can't be reached.
  def verify_credentials!
    create_session["did"]
  end

  # Creates a threadgate for a post, limiting who can reply to it to followers and
  # people the account follows. Only applies to root posts; replies inherit the gate
  # of the thread's root post.
  #
  # @param post_uri [String] the at-uri of the post to gate.
  # @return [Hash] the parsed response body if successful.
  # @raise [ArgumentError] if the at-uri is blank or malformed.
  # @raise [RuntimeError] if the post request fails.
  def create_threadgate(post_uri)
    # The threadgate's rkey must match the post's rkey.
    rkey = post_uri.to_s.split('/').last
    raise ArgumentError, "Invalid post at-uri: #{post_uri.inspect}" if rkey.blank? || !post_uri.to_s.start_with?('at://')

    create_record({
      repo: did,
      collection: "app.bsky.feed.threadgate",
      rkey: rkey,
      record: {
        "$type" => "app.bsky.feed.threadgate",
        post: post_uri,
        allow: THREADGATE_ALLOW_RULES,
        createdAt: Time.now.iso8601
      }
    })
  end

  private

  # Builds the rich-text facets for a post: every link, every @mention and every #hashtag.
  #
  # Every offset comes from the plain text the record holds, never from the raw text the author
  # typed, and #skeet renders that text once and hands this method the links from the same parse.
  #
  # Links come first, and a mention or hashtag inside a link does not get a facet of its own: a URL
  # like `…/profile/@me.bsky.social` or `…/#section` would otherwise get two facets over one range,
  # which clients render as a broken link.
  #
  # @param text [String] the plain text of the post.
  # @param links [Array<MarkdownLinks::Link>] the links from the parse that made that text.
  # @return [Array<Hash>] the facets, sorted by where they start.
  def build_facets(text, links: [])
    link_facets = self.class.link_ranges(text, links).map { |link| link_facet(text, link) }
    inside_link = link_facets.map { |facet| facet["index"]["byteStart"]...facet["index"]["byteEnd"] }

    facets = link_facets + mention_facets(text, skip: inside_link) + tag_facets(text, skip: inside_link)
    facets.sort_by { |facet| facet["index"]["byteStart"] }
  end

  # Builds one app.bsky.richtext.facet#link.
  #
  # A facet's offsets are in bytes of the UTF-8 text and MarkdownLinks::Link holds characters. One
  # accented letter is 1 character and 2 bytes, so a character offset would shift the highlight of
  # every facet after it.
  #
  # @param text [String] the plain text of the post.
  # @param link [MarkdownLinks::Link] the link to build a facet for.
  # @return [Hash] the facet.
  def link_facet(text, link)
    {
      "index" => {
        "byteStart" => text[0...link.start].bytesize,
        "byteEnd" => text[0...link.finish].bytesize
      },
      "features" => [
        { "$type" => "app.bsky.richtext.facet#link", "uri" => link.url }
      ]
    }
  end

  # Builds an app.bsky.richtext.facet#mention for each @handle the PDS can resolve.
  #
  # A handle it can't resolve is dropped: a mention facet with no DID makes the whole record
  # invalid, which would take the post down with it.
  #
  # @param text [String] the plain text of the post.
  # @param skip [Array<Range>] byte ranges already covered by a link.
  # @return [Array<Hash>] the mention facets.
  def mention_facets(text, skip: [])
    scan_facets(text, MENTION_PATTERN, skip: skip) do |match|
      did = resolve_handle(match.delete_prefix("@"))
      next if did.blank?

      { "$type" => "app.bsky.richtext.facet#mention", "did" => did }
    end
  end

  # Builds an app.bsky.richtext.facet#tag for each #hashtag.
  #
  # This doesn't use #scan_facets, because a tag's facet can be shorter than its match: the client
  # trims trailing punctuation, so "#trail." tags "trail" and the facet has to shrink with it or it
  # would highlight a character the tag doesn't contain.
  #
  # @param text [String] the plain text of the post.
  # @param skip [Array<Range>] byte ranges already covered by a link.
  # @return [Array<Hash>] the tag facets.
  def tag_facets(text, skip: [])
    facets = []

    text.to_s.scan(TAG_PATTERN) do
      match = Regexp.last_match
      start_char, = match.offset(1)
      byte_start = text[0...start_char].bytesize

      tag = match[1].sub(TRAILING_PUNCTUATION, '')
      byte_end = byte_start + tag.bytesize
      next if overlaps?(byte_start, byte_end, skip)

      # The facet covers the "#", and the tag itself doesn't.
      name = tag.sub(TAG_PREFIX, '')
      next if name.blank?
      next if SocialText.graphemes(name) > MAX_TAG_GRAPHEMES || name.bytesize > MAX_TAG_BYTES

      facets << {
        "index" => { "byteStart" => byte_start, "byteEnd" => byte_end },
        "features" => [
          { "$type" => "app.bsky.richtext.facet#tag", "tag" => name }
        ]
      }
    end

    facets
  end

  # Finds each match of a pattern's first group and builds a facet from it.
  #
  # Offsets are in bytes of the UTF-8 text, not characters.
  #
  # @param text [String] the plain text of the post.
  # @param pattern [Regexp] a pattern whose first group is the span to mark.
  # @param skip [Array<Range>] byte ranges to leave alone. A match touching one is not a facet, and
  #   the block doesn't run for it.
  # @yieldparam match [String] the matched span.
  # @yieldreturn [Hash, nil] the feature, or nil to drop the facet.
  # @return [Array<Hash>] the facets.
  def scan_facets(text, pattern, skip: [])
    facets = []

    text.to_s.scan(pattern) do
      match = Regexp.last_match
      start_char, end_char = match.offset(1)
      byte_start = text[0...start_char].bytesize
      byte_end = text[0...end_char].bytesize
      next if overlaps?(byte_start, byte_end, skip)

      feature = yield(match[1])
      next if feature.blank?

      facets << {
        "index" => { "byteStart" => byte_start, "byteEnd" => byte_end },
        "features" => [feature]
      }
    end

    facets
  end

  # Tests whether a byte range touches any of the ranges to skip.
  #
  # This compares the whole range rather than just its start, so a mention that begins before a
  # link and runs into it is still suppressed.
  #
  # @param byte_start [Integer] the start of the range.
  # @param byte_end [Integer] the end of the range, exclusive.
  # @param skip [Array<Range>] the byte ranges to avoid.
  # @return [Boolean] true if the range overlaps any of them.
  def overlaps?(byte_start, byte_end, skip)
    skip.any? { |range| byte_start < range.end && range.begin < byte_end }
  end

  # The hosts a Bluesky post URL can be on.
  POST_URL_HOSTS = ['bsky.app', 'www.bsky.app'].freeze

  # Converts a Bluesky post URL into an at-uri.
  #
  # This takes whatever someone pasted into the admin's reply and quote fields, so it has to
  # tolerate anything: a URL that doesn't parse, a profile link with no post on it, a like rather
  # than a post.
  #
  # @param post_url [String] the public Bluesky post URL.
  # @return [String, nil] the at-uri for the post, or nil if the URL doesn't name one.
  def post_url_to_at_uri(post_url)
    uri = URI.parse(post_url.to_s.strip)
    return unless POST_URL_HOSTS.include?(uri.host) && uri.path.to_s.start_with?('/profile/')

    # /profile/<did or handle>/post/<rkey>
    path_parts = uri.path.split('/')
    did_or_handle = path_parts[2]
    post_id = path_parts[4]

    return if did_or_handle.blank? || post_id.blank?
    # Anything else under /profile/ is a like, a feed or a list, not a post.
    return unless path_parts[3] == 'post'

    # A profile path can hold the DID itself, in any of its methods, or a handle we have to
    # resolve.
    return "at://#{did_or_handle}/app.bsky.feed.post/#{post_id}" if did_or_handle.start_with?('did:')

    did = resolve_handle(did_or_handle)
    return if did.blank?

    "at://#{did}/app.bsky.feed.post/#{post_id}"
  rescue URI::InvalidURIError
    nil
  end

  # Resolves a handle to its DID using the Bluesky API.
  #
  # @param handle [String] the handle to resolve.
  # @return [String, nil] the DID if resolved successfully, or nil if the handle cannot be resolved.
  def resolve_handle(handle)
    # A caption can name the same handle more than once, and there is no reason to ask twice.
    @resolved_handles ||= {}
    return @resolved_handles[handle] if @resolved_handles.key?(handle)

    @resolved_handles[handle] = begin
      response = HTTParty.get("#{@base_url}/xrpc/com.atproto.identity.resolveHandle",
                              query: { "handle" => handle },
                              timeout: RESOLVE_TIMEOUT)
      response.success? ? JSON.parse(response.body)["did"].presence : nil
    rescue StandardError
      # A handle the PDS can't resolve and a PDS that didn't answer both mean "no facet". Letting
      # a network error escape would fail the whole post over one mention.
      nil
    end
  end

  # Retrieves the post thread from the Bluesky API for a given at-uri.
  #
  # @param at_uri [String] the at-uri of the post.
  # @return [Hash] the parsed response from the Bluesky API.
  # @raise [RuntimeError] if the API request fails.
  def get_post_thread(at_uri)
    return if at_uri.blank?

    with_valid_session do
      response = HTTParty.get(
        "#{@base_url}/xrpc/app.bsky.feed.getPostThread",
        # We only need the post itself, so ask for neither its replies nor its ancestors. Without
        # these a popular post drags its whole thread down the wire.
        query: { "uri" => at_uri, "depth" => 0, "parentHeight" => 0 },
        headers: { "Authorization" => "Bearer #{access_token}" },
        timeout: REQUEST_TIMEOUT
      )

      raise UnauthorizedError, "Bluesky rejected the access token" if response.code == 401
      raise "Failed to retrieve post thread: #{response.body}" unless response.success?

      JSON.parse(response.body)
    end
  end

  # Returns the post a thread response is about, once we know the API actually found it.
  #
  # getPostThread answers 200 with a notFoundPost or a blockedPost for a post that is deleted,
  # blocked or private, and neither of those carries a cid. Digging straight in gives a reply or
  # quote with a nil uri and cid, and the failure then surfaces as an opaque "Failed to create"
  # from the record write, naming the post we were trying to send rather than the one we couldn't
  # read.
  #
  # @param thread [Hash, nil] the parsed getPostThread response.
  # @param post_url [String] the URL the caller gave us, for the error message.
  # @return [Hash] the post, with its uri and cid.
  # @raise [RuntimeError] if the thread doesn't hold a readable post.
  def thread_post!(thread, post_url)
    post = thread&.dig("thread", "post")

    if post.blank? || post["uri"].blank? || post["cid"].blank?
      raise "Could not read the Bluesky post at #{post_url}. It may be deleted, blocked or private."
    end

    post
  end

  # Creates a record in the Bluesky API for the specified collection.
  # @param record [Hash] the record data to send to the API.
  # @return [Hash] the parsed response body if successful.
  # @raise [RuntimeError] if the post request fails.
  def create_record(record)
    with_valid_session do
      headers = {
        "Authorization" => "Bearer #{access_token}",
        "Content-Type" => "application/json"
      }

      response = HTTParty.post("#{@base_url}/xrpc/com.atproto.repo.createRecord",
                               body: record.to_json,
                               headers: headers,
                               timeout: REQUEST_TIMEOUT)

      raise UnauthorizedError, "Bluesky rejected the access token" if response.code == 401
      raise "Failed to create #{record[:collection]} record: #{response.body}" unless response.success?

      JSON.parse(response.body)
    end
  end

  # Returns the cache key for the user's DID.
  #
  # @return [String] the cache key for the DID.
  def did_key
    "bluesky:#{@auth[:identifier]}:did"
  end

  # Returns the cache key for the user's access token.
  #
  # @return [String] the cache key for the access token.
  def access_token_key
    "bluesky:#{@auth[:identifier]}:access_token"
  end

  # Retrieves the access token from the cache or creates a new session to get a token.
  #
  # Memoizing on the instance is what keeps a cold cache down to a single createSession: the first
  # call writes both cache keys, and everything after it reads them.
  #
  # @return [String] the access token.
  def access_token
    @access_token ||= Rails.cache.read(access_token_key) || create_session["accessJwt"]
  end

  # Retrieves the DID from the cache or creates a new session to get the DID.
  #
  # @return [String] the DID.
  def did
    @did ||= Rails.cache.read(did_key) || create_session["did"]
  end

  # Runs a request that needs the access token, and runs it once more with a fresh session if the
  # PDS says the token is no good.
  #
  # A token can stop working before its cache entry expires — it can be revoked, or the app
  # password can be changed. Without this, every attempt for the rest of the hour fails against
  # the same dead token, which is long enough to exhaust a job's retries.
  #
  # @yield the request to run.
  # @return [Object] whatever the block returns.
  def with_valid_session
    yield
  rescue UnauthorizedError
    reset_session!
    yield
  end

  # Forgets the cached session so the next request authenticates again.
  #
  # @return [void]
  def reset_session!
    Rails.cache.delete(access_token_key)
    Rails.cache.delete(did_key)
    @access_token = nil
    @did = nil
  end

  # Creates a new session with the Bluesky API and caches the DID and access token.
  #
  # @return [Hash] the response from the session creation request.
  # @raise [AuthenticationError] if Bluesky refuses the handle and app password.
  # @raise [ConnectionError] if the PDS can't be reached.
  def create_session
    body = {
      identifier: @auth[:identifier],
      password: @auth[:password]
    }

    response = HTTParty.post("#{@base_url}/xrpc/com.atproto.server.createSession",
                             body: body.to_json,
                             headers: { "Content-Type" => "application/json" },
                             timeout: SESSION_TIMEOUT)

    unless response.success?
      raise AuthenticationError, "Unable to create a new session: #{response.code} #{response.body}"
    end

    session = JSON.parse(response.body)
    Rails.cache.write(did_key, session["did"])
    Rails.cache.write(access_token_key, session["accessJwt"], expires_in: 1.hour)
    @did = session["did"]
    @access_token = session["accessJwt"]
    session
  rescue AuthenticationError
    raise
  rescue StandardError => e
    raise ConnectionError, "Could not reach the Bluesky PDS at #{@base_url}: #{e.message}"
  end

  # Uploads a photo to the Bluesky API and returns the response blob.
  #
  # @param url [String] the URL of the photo to upload.
  # @return [Hash] the parsed response body from the photo upload request.
  # @raise [RuntimeError] if the photo fetch or upload request fails.
  def upload_photo(url)
    image_data, content_type = fetch_image(url)

    # If the image is over Bluesky's blob limit, recompress it to fit; otherwise
    # createRecord rejects the post and every retry re-uploads the same too-big blob.
    if image_data.bytesize > MAX_BLOB_SIZE
      image_data = compress_under_blob_limit(image_data)
      content_type = 'image/jpeg'
    end

    with_valid_session do
      headers = {
        "Authorization" => "Bearer #{access_token}",
        "Content-Type" => content_type
      }

      response = HTTParty.post("#{@base_url}/xrpc/com.atproto.repo.uploadBlob",
                               body: image_data,
                               headers: headers,
                               timeout: UPLOAD_TIMEOUT)

      raise UnauthorizedError, "Bluesky rejected the access token" if response.code == 401
      raise "Failed to upload photo: #{response.body}" unless response.success?

      JSON.parse(response.body)
    end
  end

  # Downloads a photo, stopping if the body runs past MAX_SOURCE_IMAGE_BYTES.
  #
  # The content type is checked because a 200 that is really an HTML error page would otherwise be
  # uploaded as a blob and fail later, against the record rather than the photo.
  #
  # @param url [String] the URL of the photo.
  # @return [Array(String, String)] the image data and its content type.
  # @raise [RuntimeError] if the fetch fails, the body is not an image, or it is too large.
  def fetch_image(url)
    body = String.new(encoding: Encoding::BINARY)
    content_type = nil
    response = nil

    # Read in fragments and stop at the limit, rather than letting an unbounded body into a
    # Sidekiq thread. Throwing leaves `response` nil, which is how the check below tells "too
    # large" from "the fetch failed".
    catch(:too_big) do
      response = HTTParty.get(url, stream_body: true, timeout: IMAGE_TIMEOUT) do |fragment|
        next unless (200..299).cover?(fragment.code.to_i)

        content_type ||= fragment.http_response['content-type'].to_s
        body << fragment.to_s.b
        throw :too_big if body.bytesize > MAX_SOURCE_IMAGE_BYTES
      end
    end

    if body.bytesize > MAX_SOURCE_IMAGE_BYTES
      raise "Image at #{url} is over the #{MAX_SOURCE_IMAGE_BYTES} byte limit"
    end
    raise "Failed to fetch image from #{url}: #{response&.code}" unless response&.success?

    content_type = content_type.to_s.split(';').first.to_s.strip
    unless content_type.start_with?('image/')
      raise "Expected an image from #{url}, got #{content_type.presence || 'no content type'}"
    end

    [body, content_type]
  end

  # Recompresses an oversized image so its blob fits under Bluesky's limit,
  # returning JPEG data. Walks through BLOB_COMPRESSION_STEPS and returns the
  # first attempt at or under the target size; if none fit, returns the smallest
  # (last) attempt, which is still far smaller than the original.
  #
  # @param image_data [String] the raw (binary) image data to compress.
  # @return [String] the recompressed JPEG data.
  def compress_under_blob_limit(image_data)
    candidate = image_data
    BLOB_COMPRESSION_STEPS.each do |step|
      candidate = recompress_image(image_data, **step)
      return candidate if candidate.bytesize <= BLOB_SIZE_TARGET
    end
    candidate
  end

  # Recompresses an image as a JPEG at the given quality, optionally scaling it
  # down first.
  #
  # @param image_data [String] the raw (binary) image data to recompress.
  # @param quality [Integer] the JPEG quality to encode at.
  # @param resize [String, nil] an optional ImageMagick geometry (e.g. '70%') to scale by.
  # @return [String] the recompressed JPEG data.
  def recompress_image(image_data, quality:, resize: nil)
    image = MiniMagick::Image.read(image_data)
    image.format('jpeg')
    image.combine_options do |img|
      img.resize(resize) if resize
      img.quality(quality.to_s)
      img.strip
    end
    image.to_blob
  end

  # Constructs the reply object for a given post URL.
  #
  # @param post_url [String] the public URL of the post to reply to.
  # @return [Hash, nil] the reply object to include in the post or nil if no post_url is provided.
  def construct_reply(post_url)
    return if post_url.blank?

    at_uri = post_url_to_at_uri(post_url)
    raise "#{post_url} is not a Bluesky post URL" if at_uri.blank?

    post = thread_post!(get_post_thread(at_uri), post_url)
    parent = { uri: post["uri"], cid: post["cid"] }

    # A reply to a reply keeps the thread's original root; a reply to a root post is its own root.
    root = post.dig("record", "reply", "root") || parent

    { root: root, parent: parent }
  end

  # Constructs the embed object for a post.
  #
  # @param photos [Array<Hash>] an array of photos, each with :url, :alt_text, :width, and :height.
  # @param quote [String, nil] the URL of the post to quote. Optional.
  # @return [Hash, nil] the constructed embed object or nil if neither photos nor quote are provided.
  def construct_embed(photos, quote)
    # Prepare embedded images if photos are provided
    embedded_images = Array(photos).take(MAX_PHOTOS).map do |photo|
      {
        image: upload_photo(photo[:url])["blob"],
        # The lexicon requires alt to be a string, and a nil there fails validation at record
        # creation with a message that names the embed rather than the photo.
        alt: photo[:alt_text].to_s,
        aspectRatio: {
          width: photo[:width],
          height: photo[:height]
        }
      }
    end

    # Construct the quote object if a quote URL is provided
    quoted_record = if quote.present?
                      at_uri = post_url_to_at_uri(quote)
                      raise "#{quote} is not a Bluesky post URL" if at_uri.blank?

                      post = thread_post!(get_post_thread(at_uri), quote)
                      { "cid" => post["cid"], "uri" => post["uri"] }
                    end

    # Construct the embed object based on the presence of photos and quote
    if embedded_images.empty? && quoted_record.blank?
      nil # No embed if both photos and quote are absent
    elsif embedded_images.any? && quoted_record.blank?
      {
        "$type" => "app.bsky.embed.images",
        "images" => embedded_images
      }
    elsif embedded_images.empty? && quoted_record.present?
      {
        "$type" => "app.bsky.embed.record",
        "record" => quoted_record
      }
    elsif embedded_images.any? && quoted_record.present?
      {
        "$type" => "app.bsky.embed.recordWithMedia",
        "media" => {
          "$type" => "app.bsky.embed.images",
          "images" => embedded_images
        },
        "record" => {
          "$type" => "app.bsky.embed.record",
          "record" => quoted_record
        }
      }
    end
  end
end
