module Admin::EntriesHelper
  def new_queue_date
    last_in_queue = Entry.queued.last&.publish_date_for_queued || Time.now
    last_in_queue + 1.day
  end

  def share_markdown(entry)
    text = "[#{entry.plain_title}](#{entry.permalink_url})"
    text << entry.body
    text.reject(&:blank?).join("\n\n")
  end

  def share_title(entry)
    entry.plain_title
  end

  def permalink_preview(entry)
    if entry.is_published?
      "https://#{@photoblog.domain}/#{entry.published_at.strftime('%Y')}/#{entry.published_at.strftime('%-m')}/#{entry.published_at.strftime('%-d')}/#{entry.id}/"
    elsif entry.is_queued? && entry.position.present? && entry.id.present?
      "https://#{@photoblog.domain}/#{entry.publish_date_for_queued.strftime('%Y')}/#{entry.publish_date_for_queued.strftime('%-m')}/#{entry.publish_date_for_queued.strftime('%-d')}/#{entry.id}/"
    elsif entry.id.present?
      "https://#{@photoblog.domain}/#{Time.now.strftime('%Y')}/#{Time.now.strftime('%-m')}/#{Time.now.strftime('%-d')}/#{entry.id}/"
    else
      "https://#{@photoblog.domain}/#{Time.now.strftime('%Y')}/#{Time.now.strftime('%-m')}/#{Time.now.strftime('%-d')}/1234/"
    end
  end
end
