class GeocodeJob < ApplicationJob
  queue_as :default

  def perform(photo)
    url = "https://maps.googleapis.com/maps/api/geocode/json?latlng=#{photo.latitude},#{photo.longitude}&key=#{ENV['google_api_key']}"
    response = JSON.parse(HTTParty.get(url).body)
    raise response['error_message'] || response['status'] if response['status'] != 'OK'

    result = response['results'][0]
    components = result['address_components']

    photo.country             = components.select { |c| c['types'].include? 'country' }.map {|c| c['long_name']}.join(', ')
    photo.locality            = components.select { |c| c['types'].include? 'locality' }.map {|c| c['long_name']}.join(', ')
    photo.sublocality         = components.select { |c| c['types'].include? 'sublocality' }.map {|c| c['long_name']}.join(', ')
    photo.neighborhood        = components.select { |c| c['types'].include? 'neighborhood' }.map {|c| c['long_name']}.join(', ')
    photo.administrative_area = components.select { |c| c['types'].include? 'administrative_area_level_1' }.map {|c| c['long_name']}.join(', ')
    photo.save
  end
end
