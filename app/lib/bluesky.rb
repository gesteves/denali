require 'mini_magick'

class Bluesky
  MAX_POST_LENGTH = 300
  MAX_PHOTOS = 4

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

  # Verifies that the text of a post is equal to or less than 300 Unicode graphemes.
  # Class method for use without authentication (e.g., validation checks).
  #
  # @param text [String] the raw text of the post with Markdown syntax.
  # @return [Boolean] true if the plain text is valid, false otherwise.
  def self.valid_post_length?(text)
    return false unless text.is_a?(String)

    post_length(text) <= MAX_POST_LENGTH
  end

  # Returns the length of the post text in Unicode graphemes.
  # Class method for use without authentication (e.g., validation checks).
  #
  # @param text [String] the raw text of the post with Markdown syntax.
  # @return [Integer] the length in Unicode graphemes.
  def self.post_length(text)
    # Parse URLs and remove Markdown, leaving only the plain text
    _, plain_text = parse_urls_for_length(text)

    # Count the Unicode graphemes in the plain text
    plain_text.each_grapheme_cluster.to_a.size
  end

  # Parses URLs in text for length calculation purposes (class method).
  # Lighter-weight version that only extracts plain text.
  #
  # @param text [String] the text to process.
  # @return [Array] an array where the first element is nil (unused), and the second element is the plain text.
  def self.parse_urls_for_length(text)
    html = markdown_to_html(text)
    plain_text = html_to_plain_text(html)
    [nil, plain_text]
  end

  # Renders Markdown text to HTML with SmartyPants processing.
  #
  # @param text [String] the Markdown text to render.
  # @return [String] the rendered HTML.
  def self.markdown_to_html(text)
    renderer = Redcarpet::Render::HTML.new(hard_wrap: false)
    markdown = Redcarpet::Markdown.new(renderer, autolink: true, no_intra_emphasis: true, fenced_code_blocks: true)
    Redcarpet::Render::SmartyPants.render(markdown.render(text))
  end

  # Converts HTML to plain text, preserving line breaks and decoding entities.
  #
  # @param html [String] the HTML to convert.
  # @return [String] the plain text.
  def self.html_to_plain_text(html)
    fragment = Nokogiri::HTML.fragment(html)
    fragment.css('br').each { |br| br.replace("\n") }
    plain_text = Sanitize.fragment(fragment.to_html).strip
    plain_text = plain_text.gsub(/ *(\n+) */, '\1')
    HTMLEntities.new.decode(plain_text)
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
    # Extract facets from the rich text provided and return them, and the plain text
    facets, plain_text = parse_facets(text)

    # Construct the reply object for the post, if provided
    reply = construct_reply(in_reply_to)

    # Construct the embed object, if provided
    embed = construct_embed(photos, quote)

    # Construct the record data for the skeet
    record_data = {
      text: plain_text,
      langs: ["en-US"],
      createdAt: Time.now.iso8601,
      facets: facets
    }

    record_data[:embed] = embed if embed.present?
    record_data[:reply] = reply if reply.present?

    record = {
      repo: did,
      collection: "app.bsky.feed.post",
      record: record_data
    }

    create_record(record)
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

  # Calculates byte offsets for a match found in a string.
  #
  # @param match_data [MatchData] the match data object.
  # @param original_text [String] the original text string where the match was found.
  # @return [Array<Integer>] the byte offsets [start_byte, end_byte].
  def byte_offsets_for_match(match_data, original_text)
    start_char_index = match_data.offset(1)[0]
    end_char_index = match_data.offset(1)[1]
    byte_start = original_text[0...start_char_index].bytesize
    byte_end = original_text[0...end_char_index].bytesize
    [byte_start, byte_end]
  end

  # Parses @mentions in the text and returns an array of app.bsky.richtext.facet#mention facets.
  #
  # @param text [String] the text to scan for mentions.
  # @return [Array<Hash>] an array of mention facets
  def parse_mentions(text)
    mention_regex = /(?:^|[$|\W])(@([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)/
    facets = []

    text.scan(mention_regex) do |m|
      byte_start, byte_end = byte_offsets_for_match($~, text)
      did = resolve_handle(m[0][1..])
      next unless did

      facets << {
        "index" => { "byteStart" => byte_start, "byteEnd" => byte_end },
        "features" => [
          { "$type" => "app.bsky.richtext.facet#mention", "did" => did }
        ]
      }
    end

    facets
  end

  # Parses URLs in the text and returns an array of app.bsky.richtext.facet#link facets, and the text with Markdown removed.
  #
  # @param text [String] the text to scan for URLs.
  # @return [Array] an array where the first element is an array of URL facets, and the second element is the plain text with Markdown removed.
  def parse_urls(text)
    links = []

    # Step 1: Render Markdown to HTML
    html = self.class.markdown_to_html(text)

    # Step 2: Extract <a> tags using Nokogiri, store their labels and URLs
    doc = Nokogiri::HTML.fragment(html)
    doc.css('a').each do |link|
      links << { label: link.text.strip, url: link['href'] }
    end

    # Step 3: Convert HTML to plain text
    plain_text = self.class.html_to_plain_text(html)

    # Step 4: Find each link's label's position in the plain text, and construct facets
    facets = []
    links.each do |link|
      label = link[:label]
      url = link[:url]

      # Use a match iterator to find all occurrences of the label
      plain_text.enum_for(:scan, Regexp.new(Regexp.escape(label))).each do
        match_start = Regexp.last_match.begin(0)
        match_end = Regexp.last_match.end(0)

        # Convert character offsets to byte offsets
        byte_start = plain_text[0...match_start].bytesize
        byte_end = plain_text[0...match_end].bytesize

        # Add the facet to the array
        facets << {
          "index" => { "byteStart" => byte_start, "byteEnd" => byte_end },
          "features" => [
            { "$type" => "app.bsky.richtext.facet#link", "uri" => url }
          ]
        }
      end
    end

    [facets, plain_text]
  end

  # Parses #hashtags in the text and returns an array of app.bsky.richtext.facet#tag facets.
  #
  # @param text [String] the text to scan for hashtags.
  # @return [Array<Hash>] an array of tag facets.
  def parse_tags(text)
    tag_regex = /(?:^|[$|\W])(#\w+)/
    facets = []

    text.scan(tag_regex) do |m|
      byte_start, byte_end = byte_offsets_for_match($~, text)
      facets << {
        "index" => { "byteStart" => byte_start, "byteEnd" => byte_end },
        "features" => [
          { "$type" => "app.bsky.richtext.facet#tag", "tag" => m[0][1..] } # Strip leading #
        ]
      }
    end

    facets
  end

  # Parses mentions, URLs, and hashtags in the text and returns their facets and plain text.
  #
  # @param text [String] the text to scan for facets.
  # @return [Array] an array where the first element is all facets, and the second element is the plain text.
  def parse_facets(text)
    url_facets, plain_text = parse_urls(text)
    mention_facets = parse_mentions(plain_text) # Mentions work with plain text
    tag_facets = parse_tags(plain_text)         # Tags also work with plain text

    [url_facets + mention_facets + tag_facets, plain_text]
  end

  # Converts a Bluesky post URL into an at-uri.
  #
  # @param post_url [String] the public Bluesky post URL.
  # @return [String] the at-uri for the post.
  # @raise [ArgumentError] if the post URL is invalid.
  def post_url_to_at_uri(post_url)
    # Validate the URL
    uri = URI.parse(post_url)
    return unless uri.host == 'bsky.app' && uri.path.start_with?('/profile/')

    # Extract components from the URL
    path_parts = uri.path.split('/')
    did_or_handle = path_parts[2] # The part after /profile/
    post_id = path_parts[4]       # The part after /post/

    # Ensure we have a valid DID/handle and  post ID
    return if did_or_handle.blank? || post_id.blank?

    # If the profile path contains a DID, construct the at-uri directly
    if did_or_handle.start_with?('did:plc:')
      "at://#{did_or_handle}/app.bsky.feed.post/#{post_id}"
    else
      # Resolve the handle to a DID
      did = resolve_handle(did_or_handle)
      return if did.blank?

      "at://#{did}/app.bsky.feed.post/#{post_id}"
    end
  end

  # Resolves a handle to its DID using the Bluesky API.
  #
  # @param handle [String] the handle to resolve.
  # @return [String, nil] the DID if resolved successfully, or nil if the handle cannot be resolved.
  def resolve_handle(handle)
    response = HTTParty.get("#{@base_url}/xrpc/com.atproto.identity.resolveHandle", query: { "handle" => handle })
    return nil unless response.success?

    JSON.parse(response.body)["did"]
  rescue JSON::ParserError
    nil
  end

  # Retrieves the post thread from the Bluesky API for a given at-uri.
  #
  # @param at_uri [String] the at-uri of the post.
  # @return [Hash] the parsed response from the Bluesky API.
  # @raise [RuntimeError] if the API request fails.
  def get_post_thread(at_uri)
    return if at_uri.blank?
    response = HTTParty.get(
      "#{@base_url}/xrpc/app.bsky.feed.getPostThread",
      query: { "uri" => at_uri },
      headers: { "Authorization" => "Bearer #{access_token}" }
    )

    if response.success?
      JSON.parse(response.body)
    else
      raise "Failed to retrieve post thread: #{response.body}"
    end
  end

  # Creates a record in the Bluesky API for the specified collection.
  # @param record [Hash] the record data to send to the API.
  # @return [Hash] the parsed response body if successful.
  # @raise [RuntimeError] if the post request fails.
  def create_record(record)
    headers = {
      "Authorization" => "Bearer #{access_token}",
      "Content-Type" => "application/json"
    }

    response = HTTParty.post("#{@base_url}/xrpc/com.atproto.repo.createRecord",
                             body: record.to_json,
                             headers: headers)

    if response.success?
      JSON.parse(response.body)
    else
      raise "Failed to create #{record[:collection]} record: #{response.body}"
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
  # @return [String] the access token.
  def access_token
    Rails.cache.read(access_token_key) || create_session["accessJwt"]
  end

  # Retrieves the DID from the cache or creates a new session to get the DID.
  #
  # @return [String] the DID.
  def did
    Rails.cache.read(did_key) || create_session["did"]
  end

  # Creates a new session with the Bluesky API and caches the DID and access token.
  #
  # @return [Hash] the response from the session creation request.
  # @raise [RuntimeError] if the session creation request fails.
  def create_session
    body = {
      identifier: @auth[:identifier],
      password: @auth[:password]
    }

    response = HTTParty.post("#{@base_url}/xrpc/com.atproto.server.createSession", body: body.to_json, headers: { "Content-Type" => "application/json" })
    if response.success?
      response = JSON.parse(response.body)
      Rails.cache.write(did_key, response["did"])
      Rails.cache.write(access_token_key, response["accessJwt"], expires_in: 1.hour)
      response
    else
      raise "Unable to create a new session."
    end
  end

  # Uploads a photo to the Bluesky API and returns the response blob.
  #
  # @param url [String] the URL of the photo to upload.
  # @return [Hash] the parsed response body from the photo upload request.
  # @raise [RuntimeError] if the photo fetch or upload request fails.
  def upload_photo(url)
    image_response = HTTParty.get(url)
    raise "Failed to fetch image from #{url}: #{image_response.code}" unless image_response.success?

    image_data = image_response.body
    content_type = image_response.content_type || 'image/jpeg'

    # If the image is over Bluesky's blob limit, recompress it to fit; otherwise
    # createRecord rejects the post and every retry re-uploads the same too-big blob.
    if image_data.bytesize > MAX_BLOB_SIZE
      image_data = compress_under_blob_limit(image_data)
      content_type = 'image/jpeg'
    end

    headers = {
      "Authorization" => "Bearer #{access_token}",
      "Content-Type" => content_type
    }

    response = HTTParty.post("#{@base_url}/xrpc/com.atproto.repo.uploadBlob", body: image_data, headers: headers)

    if response.success?
      JSON.parse(response.body)
    else
      raise "Failed to upload photo: #{response.body}"
    end
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

    # Convert the URL to an at-uri
    at_uri = post_url_to_at_uri(post_url)
    return if at_uri.blank?

    # Fetch the post thread data
    thread = get_post_thread(at_uri)

    # Check if the post has a reply object in its record
    post_record = thread.dig("thread", "post", "record")
    if post_record&.key?("reply")
      {
        root: post_record["reply"]["root"],
        parent: {
          uri: thread.dig("thread", "post", "uri"),
          cid: thread.dig("thread", "post", "cid")
        }
      }
    else
      {
        root: {
          uri: thread.dig("thread", "post", "uri"),
          cid: thread.dig("thread", "post", "cid")
        },
        parent: {
          uri: thread.dig("thread", "post", "uri"),
          cid: thread.dig("thread", "post", "cid")
        }
      }
    end
  end

  # Constructs the embed object for a post.
  #
  # @param photos [Array<Hash>] an array of photos, each with :url, :alt_text, :width, and :height.
  # @param quote [String, nil] the URL of the post to quote. Optional.
  # @return [Hash, nil] the constructed embed object or nil if neither photos nor quote are provided.
  def construct_embed(photos, quote)
    # Prepare embedded images if photos are provided
    embedded_images = photos.take(4).map do |photo|
      {
        image: upload_photo(photo[:url])["blob"],
        alt: photo[:alt_text],
        aspectRatio: {
          width: photo[:width],
          height: photo[:height]
        }
      }
    end

    # Construct the quote object if a quote URL is provided
    quoted_record = if quote.present?
                      # Convert the quote URL to an at-uri
                      at_uri = post_url_to_at_uri(quote)

                      # Fetch the post thread and get the record's URI and CID
                      thread = get_post_thread(at_uri)
                      {
                        "cid" => thread&.dig("thread", "post", "cid"),
                        "uri" => thread&.dig("thread", "post", "uri")
                      }.compact
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
