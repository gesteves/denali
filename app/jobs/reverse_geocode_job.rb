class ReverseGeocodeJob < ApplicationJob
  queue_as :default

  def perform(entry)
    tags = []
    entry.photos.each do |p|
      if p.latitude.present? && p.longitude.present? && entry.show_in_map?
        tags << geocode(p.latitude, p.longitude)
      end
    end
    tags.flatten!
    entry.location_list = tags
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
