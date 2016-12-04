class ReverseGeocodeJob < ApplicationJob
  queue_as :default

  def perform(entry)
    entry.location_list = entry.photos.select { |p| p.latitude.present? && p.longitude.present? }.map { |p| geocode(p.latitude, p.longitude) }.flatten.uniq
    entry.save
  end

  def geocode(lat, lon)
    url = "https://maps.googleapis.com/maps/api/geocode/json?latlng=#{lat},#{lon}&key=#{ENV['google_maps_api_key']}"
    response = JSON.parse(HTTParty.get(url).body)
    if response['status'] == 'OK'
       response['results'][0]['address_components'].select { |c| c['types'].include? 'political' }.map { |c| c['long_name']}
    else
      []
    end
  end
end
