class TwitterWorker < BufferWorker

  def perform(entry_id, now = false)
    entry = Entry.published.find(entry_id)
    max_length = 230 # 280 characters - 25 for the image url - 25 for the permalink url
    caption = entry.tweet_text.present? ? entry.tweet_text : entry.plain_title
    text = "#{truncate(caption.gsub(/\s+&\s+/, ' and '), length: max_length, omission: '…')} #{entry.permalink_url}"
    now = Rails.env.production? ? now : false
    post_to_buffer('twitter', text: text, now: now)
  end
end
