class FiveHundredJob < ApplicationJob
  queue_as :default

  def perform(entry)
    consumer = OAuth::Consumer.new(ENV['fivehundredpx_consumer_key'], ENV['fivehundredpx_consumer_secret'], { site: 'https://api.500px.com' })
    access_token = OAuth::AccessToken.new(consumer, ENV['fivehundredpx_access_token'], ENV['fivehundredpx_access_token_secret'])

    opts = {
      name: entry.title,
      tags: entry.tag_list.join(','),
      privacy: 0
    }

    if entry.body.present?
      opts[:description] = "#{entry.plain_body}\n\n#{permalink_url(entry)}"
    else
      opts[:description] = permalink_url(entry)
    end

    entry.photos.each do |p|
      response = access_token.post('https://api.500px.com/v1/photos', opts)
      upload_photo(p, response.body) if response.code == '200'
    end
  end

  def upload_photo(photo, response_body)
    body = JSON.parse(response_body)
    opts = {
      upload_key: body['upload_key'],
      photo_id: body['photo']['id'],
      file: File.new(open(photo.original_url).path),
      consumer_key: ENV['fivehundredpx_consumer_key'],
      access_key: ENV['fivehundredpx_access_token']
    }
    HTTMultiParty.post('http://upload.500px.com/v1/upload', body: opts)
  end
end
