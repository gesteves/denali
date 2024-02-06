class Bluesky
  def initialize(base_url:, email:, password:)
    @base_url = base_url
    @auth = {
      identifier: email,
      password: password
    }
  end

  def skeet(text:, photos: [])
    embedded_images = photos.take(4).map do |photo|
      cid = upload_photo(photo[:url])["blob"]["ref"]["$link"]
      {
        image: {
            cid: cid,
            mimeType: "image/jpeg"
        },
        alt: photo[:alt_text],
        aspectRatio: {
          width: photo[:width],
          height: photo[:height]
        }
      }
    end

    facets = parse_facets(text)

    request_body = {
      repo: did,
      collection: "app.bsky.feed.post",
      record: {
        text: text,
        langs: ["en-US"],
        createdAt: Time.now.iso8601,
        facets: facets
      }
    }

    request_body[:record][:embed] = {
      "$type" => "app.bsky.embed.images",
      "images" => embedded_images
    } unless embedded_images.empty?

    headers = {
      "Authorization" => "Bearer #{access_token}",
      "Content-Type" => "application/json"
    }

    response = HTTParty.post("#{@base_url}/xrpc/com.atproto.repo.createRecord",
                              body: request_body.to_json,
                              headers: headers)

    if response.success?
      JSON.parse(response.body)
    else
      raise "Failed to post to Bluesky: #{response.body}"
    end
  end

  private

  def byte_offsets_for_match(match_data, original_text)
    start_char_index = match_data.offset(1)[0]
    end_char_index = match_data.offset(1)[1]
    byte_start = original_text[0...start_char_index].bytesize
    byte_end = original_text[0...end_char_index].bytesize
    [byte_start, byte_end]
  end
  
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
  
  def parse_urls(text)
    spans = []
    url_regex = /[$|\W](https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&\/=]*[-a-zA-Z0-9@%_\+~#\/=])?)/
    text.scan(url_regex) do |m|
      byte_start, byte_end = byte_offsets_for_match($~, text)
      spans << {
        "start" => byte_start,
        "end" => byte_end,
        "url" => m[0]
      }
    end
    spans
  end

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
  
  def parse_facets(text)
    facets = []
    parse_mentions(text).each do |m|
      response = HTTParty.get("https://bsky.social/xrpc/com.atproto.identity.resolveHandle", query: {"handle" => m["handle"]})
      
      next if response.code == 400
      did = JSON.parse(response.body)["did"]
      
      facets << {
        "index" => {
          "byteStart" => m["start"],
          "byteEnd" => m["end"],
        },
        "features" => [
          {
            "$type" => "app.bsky.richtext.facet#mention",
            "did" => did
          }
        ]
      }
    end
  
    parse_urls(text).each do |u|
      facets << {
        "index" => {
          "byteStart" => u["start"],
          "byteEnd" => u["end"],
        },
        "features" => [
          {
            "$type" => "app.bsky.richtext.facet#link",
            "uri" => u["url"]
          }
        ]
      }
    end
  
    parse_tags(text).each do |t|
      facets << {
        "index" => {
          "byteStart" => t["start"],
          "byteEnd" => t["end"],
        },
        "features" => [
          {
            "$type" => "app.bsky.richtext.facet#tag",
            "tag" => t["tag"]
          }
        ]
      }
    end
  
    facets
  end 

  def did_key
    "bluesky:#{@auth[:identifier]}:did"
  end

  def access_token_key
    "bluesky:#{@auth[:identifier]}:access_token"
  end

  def access_token
    Rails.cache.read(access_token_key) || create_session["accessJwt"]
  end

  def did
    Rails.cache.read(did_key) || create_session["did"]
  end

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
