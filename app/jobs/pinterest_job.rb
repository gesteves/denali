class PinterestJob < EntryJob

  queue_as :default

  def perform(entry)
    opts = {
      board: ENV['pinterest_board_id'],
      note: entry.title,
      link: permalink_url(entry)
    }
    entry.photos.each do |p|
      opts[:image_url] = p.original_url
      HTTParty.post('https://api.pinterest.com/v1/pins/', query: opts, headers: { 'Authorization' => "BEARER #{ENV['pinterest_token']}" })
    end
  end
end
