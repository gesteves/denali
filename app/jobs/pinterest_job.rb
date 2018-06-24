class PinterestJob < ApplicationJob
  queue_as :default

  def perform(entry)
    return if !entry.is_published? || !entry.is_photo? || !Rails.env.production? || ENV['pinterest_token'].blank?
    opts = {
      board: ENV['pinterest_board_id'],
      note: entry.plain_title,
      link: entry.permalink_url,
      image_url: entry.photos.first.url(w: 2048)
    }
    response = HTTParty.post('https://api.pinterest.com/v1/pins/', query: opts, headers: { 'Authorization' => "BEARER #{ENV['pinterest_token']}" })
    if response.code >= 400
      logger.tagged('Social', 'Pinterest') { logger.error response.body }
    else
      data = JSON.parse(response.body)['data']
      logger.tagged('Social', 'Pinterest') { logger.info { "Pin #{data['id']} created" } }
    end
  end
end
