class FacebookWorker < BufferWorker

  def perform(entry_id, now = false)
    entry = Entry.published.find(entry_id)
    text = []
    text << entry.plain_title
    text << entry.plain_body if entry.body.present?
    text << entry.permalink_url
    text = text.join("\n\n")
    now = Rails.env.production? ? now : false
    post_to_buffer('facebook', text: text, now: now)
  end
end
