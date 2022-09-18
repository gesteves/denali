class NativeLandsWorker < ApplicationWorker

  def perform(photo_id)
    photo = Photo.find(photo_id)
    return if !photo.has_location?
    raise UnprocessedPhotoError unless photo.has_dimensions?
    url = "https://native-land.ca/wp-json/nativeland/v1/api/index.php?maps=territories&position=#{photo.latitude},#{photo.longitude}"
    response = HTTParty.get(url)
    if response.code >= 400
      raise "Native Lands API request failed: #{response.body}"
    else
      response = JSON.parse(response.body)
      territories = response.select { |t| t['type'] == 'Feature' }.map { |t| t.dig('properties', 'Name') }.compact.map { |t| HTMLEntities.new.decode(t) }
      if territories.present?
        photo.territories = territories.to_json
        photo.save!
      end
    end
  end
end
