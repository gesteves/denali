class NationalParkWorker < ApplicationWorker

  def perform(photo_id)
    photo = Photo.find(photo_id)
    raise UnprocessedPhotoError unless photo.processed?
    return if ENV['nps_api_key'].blank?

    if photo.location.blank?
      photo.park = nil
      photo.save!
      return
    end

    code = photo.location.downcase
    return unless code.match? /^[a-z]{4,10}$/

    data = fetch_park(code)
    return if data.blank?

    park = Park.find_by_code(code)
    if park.present?
      park.update(
        full_name: data['fullName'],
        short_name: data['name'],
        code: data['parkCode'].downcase,
        designation: data['designation'],
        url: data['url'],
        slug: data['fullName'].parameterize
      )
    else
      park = Park.new(
        full_name: data['fullName'],
        short_name: data['name'],
        display_name: data['fullName'],
        code: data['parkCode'].downcase,
        designation: data['designation'],
        url: data['url'],
        slug: data['fullName'].parameterize
      )
      park.save!
    end
    photo.park = park
    photo.save!
  end

  private
  def fetch_park(code)
    return if code.blank?
    url = "https://developer.nps.gov/api/v1/parks?parkCode=#{code}&api_key=#{ENV['nps_api_key']}"
    response = HTTParty.get(url)
    raise if response.code >= 400
    data = JSON.parse(response.body)['data']
    data&.find { |p| p['parkCode'].downcase == code.downcase }
  end
end
