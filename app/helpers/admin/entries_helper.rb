module Admin::EntriesHelper

  def share_markdown(entry)
    text = []
    text << "[#{entry.plain_title}](#{entry.permalink_url})"
    text << entry.body
    text.reject(&:blank?).join("\n\n")
  end

  def permalink_preview(entry)
    if entry.is_published?
      "https://#{ENV['domain']}/#{entry.published_at.strftime('%Y')}/#{entry.published_at.strftime('%-m')}/#{entry.published_at.strftime('%-d')}/#{entry.id}/"
    elsif entry.is_queued? && entry.position.present? && entry.id.present? && entry.publish_date_for_queued.present?
      "https://#{ENV['domain']}/#{entry.publish_date_for_queued.strftime('%Y')}/#{entry.publish_date_for_queued.strftime('%-m')}/#{entry.publish_date_for_queued.strftime('%-d')}/#{entry.id}/"
    elsif entry.id.present?
      "https://#{ENV['domain']}/#{Time.current.strftime('%Y')}/#{Time.current.strftime('%-m')}/#{Time.current.strftime('%-d')}/#{entry.id}/"
    else
      "https://#{ENV['domain']}/#{Time.current.strftime('%Y')}/#{Time.current.strftime('%-m')}/#{Time.current.strftime('%-d')}/1234/"
    end
  end
end
