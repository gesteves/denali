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
    url = "https://api.mapbox.com/geocoding/v5/mapbox.places/#{lon},#{lat}.json?access_token=#{ENV['mapbox_api_token']}"
    request = HTTParty.get(url)
    if request.code == 200
      response = JSON.parse(request.body)
      response['features'][0]['context'].reject { |c| c['id'] =~ /postcode/ }.map { |c| c['text'] }
    end
  end
end
