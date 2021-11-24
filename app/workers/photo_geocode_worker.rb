class PhotoGeocodeWorker < ApplicationWorker

  def perform(photo_id)
    photo = Photo.find(photo_id)
    return if ENV['google_api_key'].blank? || !photo.has_location?
    raise UnprocessedPhotoError unless photo.processed?
    url = "https://maps.googleapis.com/maps/api/geocode/json?latlng=#{photo.latitude},#{photo.longitude}&key=#{ENV['google_api_key']}"
    response = JSON.parse(Typhoeus.get(url).body)
    if response['status'] != 'OK'
      raise "Geocode request failed: #{response.to_s}"
    else
      result = response['results'][0]
      components = result['address_components']

      photo.country             = components.find { |c| c['types'].include? 'country' }&.dig('long_name')
      photo.locality            = components.find { |c| c['types'].include?('locality') || c['types'].include?('postal_town') }&.dig('long_name')
      photo.sublocality         = components.find { |c| c['types'].include? 'sublocality' }&.dig('long_name')
      photo.neighborhood        = components.find { |c| c['types'].include? 'neighborhood' }&.dig('long_name')
      photo.administrative_area = components.find { |c| c['types'].include? 'administrative_area_level_1' }&.dig('long_name')
      photo.postal_code         = components.find { |c| c['types'].include? 'postal_code' }&.dig('long_name')

      photo.save!
    end
  end
end
