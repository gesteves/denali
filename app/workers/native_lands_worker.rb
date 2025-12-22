class NativeLandsWorker < ApplicationWorker

  def perform(photo_id)
    return if ENV['NATIVE_LAND_API_KEY'].blank?
    photo = Photo.find(photo_id)
    return unless photo.has_location?
    raise UnprocessedPhotoError unless photo.has_dimensions?

    lat = photo.latitude.round(2)
    lng = photo.longitude.round(2)
    cache_key = "native_lands/#{lat}/#{lng}"

    response_data = Rails.cache.fetch(cache_key, expires_in: 1.day) do
      fetch_from_api(lat, lng)
    end

    return if response_data.blank?

    territories = response_data.map do |data|
      territory = Territory.find_or_initialize_by(slug: data[:slug])
      territory.update!(name: data[:name], url: data[:url])
      territory
    end

    photo.territories = territories
    CaptionValidityWorker.perform_async(photo.entry_id) if photo.entry_id.present?
  end

  private

  def fetch_from_api(lat, lng)
    url = "https://native-land.ca/wp-json/nativeland/v1/api/index.php?maps=territories&position=#{lat},#{lng}&key=#{ENV['NATIVE_LAND_API_KEY']}"
    response = HTTParty.get(url)

    if response.code >= 400
      raise "Native Lands API request failed: #{response.body}"
    end

    parsed = JSON.parse(response.body)
    parsed.select { |t| t['type'] == 'Feature' }.map do |t|
      {
        slug: t.dig('properties', 'Slug'),
        name: HTMLEntities.new.decode(t.dig('properties', 'Name')),
        url: t.dig('properties', 'description')
      }
    end.compact
  end
end
