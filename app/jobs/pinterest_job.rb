class PinterestJob < ApplicationJob
  queue_as :default

  def perform(entry)
    opts = {
      board: ENV['pinterest_board_id'],
      note: entry.plain_title,
      link: entry.permalink_url,
      image_url: entry.photos.first.original_url
    }
    response = HTTParty.post('https://api.pinterest.com/v1/pins/', query: opts, headers: { 'Authorization' => "BEARER #{ENV['pinterest_token']}" })
    if response.code >= 400
      raise response.body
    end
  end
end
