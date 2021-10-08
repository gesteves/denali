class ImgixPurgeWorker < ApplicationWorker

  def perform(photo_id)
    photo = Photo.find(photo_id)
    return if ENV['imgix_purge_api_key'].blank?

    headers = {
      "Authorization": "Bearer #{ENV['imgix_purge_api_key']}",
      "Content-Type": "application/vnd.api+json",
    }
    payload = {
      "data": {
        "type": "purges",
        "attributes": {
          "url": Ix.path(photo.image.key).to_url
        }
      }
    }

    response = HTTParty.post("https://api.imgix.com/api/v1/purge", body: payload.to_json, headers: headers)

    if response.code >= 400
      raise "Failed to purge image: #{response.body}"
    end
  end
end
