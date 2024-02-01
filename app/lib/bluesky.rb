class Bluesky
  def initialize(base_url:, email:, password:)
    @base_url = base_url
    @auth = {
      identifier: email,
      password: password
    }
  end

  def skeet(text:, photos: [])
    embedded_images = photos.take(4).map do |image_hash|
      cid = upload_photo(image_hash[:url])["blob"]["ref"]["$link"]
      {
        image: {
          cid: cid,
          mimeType: "image/jpeg"
        },
        alt: image_hash[:alt_text]
      }
    end
  
    # Regular expression to find URLs in the text
    urls = text.scan(/https?:\/\/\S+/)
  
    request_body = {
      repo: did,
      collection: "app.bsky.feed.post",
      record: {
        text: text,
        createdAt: Time.now.iso8601
      }
    }
  
    request_body[:record][:embed] = {
      "$type" => "app.bsky.embed.images",
      "images" => embedded_images
    } unless embedded_images.empty?
  
    if urls.any?
      request_body[:record][:facets] = []
  
      # Add facets for each URL found in the text
      urls.each do |url|
        title = url # You can customize this to extract a title if needed
        facet = {
          "features" => [
            {
              "uri" => url,
              "$type" => "app.bsky.richtext.facet#link"
            }
          ],
          "index" => {
            "byteStart" => text.index(url),
            "byteEnd" => text.index(url) + url.length
          }
        }
        request_body[:record][:facets] << facet
      end
    end
  
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
