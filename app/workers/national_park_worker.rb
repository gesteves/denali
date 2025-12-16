class NationalParkWorker < ApplicationWorker
  sidekiq_options retry: 5

  def perform(photo_id, park_code)
    photo = Photo.find(photo_id)
    raise UnprocessedPhotoError unless photo.has_dimensions?
    return if ENV['NPS_API_KEY'].blank?
    return if park_code.blank?

    code = park_code.downcase
    return unless code.match?(/^[a-z]{4,10}$/)

    data = fetch_park(code)
    return if data.blank?

    park = Park.find_or_create_by(code: code) do |p|
      p.full_name = data['fullName']
      p.short_name = data['name']
      p.display_name = data['fullName']
      p.designation = data['designation']
      p.url = data['url']
      p.slug = data['fullName'].parameterize
    end
    photo.park = park
    photo.save!
  end

  private
  def fetch_park(code)
    return if code.blank?
    url = "https://developer.nps.gov/api/v1/parks?parkCode=#{code}&api_key=#{ENV['NPS_API_KEY']}"
    response = HTTParty.get(url)
    raise if response.code >= 400
    data = JSON.parse(response.body)['data']
    data&.find { |p| p['parkCode'].downcase == code.downcase }
  end
end
