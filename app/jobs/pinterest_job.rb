class PinterestJob < ApplicationJob
  queue_as :default

  def perform(entry)
    all_tags = entry.tag_list + entry.equipment_list + entry.location_list
    all_tags.map! { |t| "##{t.gsub(/[\s-]/, '')}" }
    opts = {
      board: ENV['pinterest_board_id'],
      note: "#{entry.plain_title} #{all_tags.join(' ')}",
      link: entry.permalink_url,
      image_url: entry.photos.first.url(w: 2048)
    }
    response = HTTParty.post('https://api.pinterest.com/v1/pins/', query: opts, headers: { 'Authorization' => "BEARER #{ENV['pinterest_token']}" })
    if response.code >= 400
      raise response.body
    end
  end
end
