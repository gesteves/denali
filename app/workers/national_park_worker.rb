class NationalParkWorker < ApplicationWorker

  def perform(photo_id)
    photo = Photo.find(photo_id)
    return if photo.location.blank?
    return if ENV['nps_api_key'].blank?
    raise UnprocessedPhotoError unless photo.processed?

    return if ENV['nps_api_key'].blank?

    code = photo.location&.downcase

    if code.blank?
      photo.park = nil
      photo.save!
      return
    end

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