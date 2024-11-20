class Bluesky
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

  # Skeets (sorry, Jay) with optional photos to Bluesky.
  #
  # @param text [String] the text of the post.
  # @param photos [Array<Hash>] an optional array of hashes representing photos.
  #   Each hash should include :url, :alt_text, :width, and :height.
  # @return [Hash] the parsed response body if successful.
  # @raise [RuntimeError] if the post request fails.
  def skeet(text:, photos: [])
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

    facets, plain_text = parse_facets(text)
  
    record_data = {
      text: plain_text,
      langs: ["en-US"],
      createdAt: Time.now.iso8601,
      facets: facets
    }
  
    record_data[:embed] = {
      "$type" => "app.bsky.embed.images",
      "images" => embedded_images
    } unless embedded_images.empty?
  
    record = {
      repo: did,
      collection: "app.bsky.feed.post",
      record: record_data
    }
  
    create_record(record)
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

  # Parses @mentions in the text and returns their byte offsets and handles.
  #
  # @param text [String] the text to scan for mentions.
  # @return [Array<Hash>] an array of hashes containing mention data including byte offsets and handles.
  def parse_mentions(text)
    spans = []
    mention_regex = /[$|\W](@([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)/
    text.scan(mention_regex) do |m|
      byte_start, byte_end = byte_offsets_for_match($~, text)
      spans << {
        "start" => byte_start,
        "end" => byte_end,
        "handle" => m[0][1..]
      }
    end
    spans
  end

  # Parses URLs, in the text and returns their byte offsets and associated data.
  #
  # @param text [String] the text to scan for URLs.
  # @return [Array<Hash>] an array of hashes containing URL data, including byte offsets and the URLs.
  def parse_urls(text)
    links = []
  
    # Step 1: Render Markdown to HTML
    renderer = Redcarpet::Render::HTML.new(hard_wrap: false)
    markdown = Redcarpet::Markdown.new(renderer, autolink: true, no_intra_emphasis: true, fenced_code_blocks: true)
    html = Redcarpet::Render::SmartyPants.render(markdown.render(text))
  
    # Step 2: Extract <a> tags using Nokogiri
    doc = Nokogiri::HTML.fragment(html)
    doc.css('a').each do |link|
      links << { label: link.text.strip, url: link['href'] }
    end
  
    # Step 3: Convert HTML to plain text with preserved line breaks
    fragment = Nokogiri::HTML.fragment(html)
    fragment.css('br').each { |br| br.replace("\n") }
    plain_text = Sanitize.fragment(fragment.to_html).strip
    plain_text = plain_text.gsub(/ *(\n+) */, '\1')
  
    # Step 4: Find each label's position in the plain text
    spans = []
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
    
        # Add the span for the link
        spans << {
          "start" => byte_start,
          "end" => byte_end,
          "url" => url
        }
      end
    end
    
    [spans, plain_text]
  end  

  # Parses #hashtags in the text and returns their byte offsets and tags.
  #
  # @param text [String] the text to scan for hashtags.
  # @return [Array<Hash>] an array of hashes containing tag data including byte offsets and the tags.
  def parse_tags(text)
    spans = []
    tag_regex = /[$|\W](#\w+)/
    text.scan(tag_regex) do |m|
      byte_start, byte_end = byte_offsets_for_match($~, text)
      spans << {
        "start" => byte_start,
        "end" => byte_end,
        "tag" => m[0][1..] # Strip the leading # symbol
      }
    end
    spans
  end

  # Parses mentions, URLs, and hashtags in the text and converts them into facets.
  #
  # @param text [String] the text to scan for facets.
  # @return [Array<Hash>] an array of facet hashes, including mention, URL, and tag facets.
  def parse_facets(text)
    url_spans, plain_text = parse_urls(text)
    facets = []
  
    # Add URL facets
    url_spans.each do |u|
      next unless u["url"] =~ /\Ahttps?:\/\// # Ensure the URL is valid
  
      facets << {
        "index" => {
          "byteStart" => u["start"],
          "byteEnd" => u["end"]
        },
        "features" => [
          {
            "$type" => "app.bsky.richtext.facet#link",
            "uri" => u["url"]
          }
        ]
      }
    end
  
    # Add mention facets
    parse_mentions(plain_text).each do |m|
      did = resolve_handle(m["handle"])
      next unless did
  
      facets << {
        "index" => {
          "byteStart" => m["start"],
          "byteEnd" => m["end"]
        },
        "features" => [
          {
            "$type" => "app.bsky.richtext.facet#mention",
            "did" => did
          }
        ]
      }
    end
  
    # Add hashtag facets
    parse_tags(plain_text).each do |t|
      facets << {
        "index" => {
          "byteStart" => t["start"],
          "byteEnd" => t["end"]
        },
        "features" => [
          {
            "$type" => "app.bsky.richtext.facet#tag",
            "tag" => t["tag"]
          }
        ]
      }
    end
  
    [facets, plain_text]
  end  

  # Resolves a handle to its DID using the Bluesky API.
  #
  # @param handle [String] the handle to resolve.
  # @return [String, nil] the DID if resolved successfully, or nil if the handle cannot be resolved.
  def resolve_handle(handle)
    response = HTTParty.get("#{@base_url}/xrpc/com.atproto.identity.resolveHandle", query: { "handle" => handle })

    return nil if response.code == 400
    JSON.parse(response.body)["did"]
  end

  # Creates a record in the Bluesky API for the specified collection.
  #  # @param record [Hash] the record data to send to the API.
  # @return [Hash] the parsed response body if successful.
  # @raise [RuntimeError] if the post request fails.
  def create_record(record)
    headers = {
      "Authorization" => "Bearer #{access_token}",
      "Content-Type" => "application/json"
    }

    puts record.to_json

    response = HTTParty.post("#{@base_url}/xrpc/com.atproto.repo.createRecord",
                             body: record.to_json,
                             headers: headers)

    if response.success?
      JSON.parse(response.body)
    else
      raise "Failed to create record: #{response.body}"
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
  # @raise [RuntimeError] if the photo upload request fails.
  def upload_photo(url)
    image_data = HTTParty.get(url).body

    headers = {
      "Authorization" => "Bearer #{access_token}",
      "Content-Type" => "image/jpeg"
    }

    response = HTTParty.post("#{@base_url}/xrpc/com.atproto.repo.uploadBlob", body: image_data, headers: headers)

    if response.success?
      JSON.parse(response.body)
    else
      raise "Failed to upload photo: #{response.body}"
    end
  end
end
