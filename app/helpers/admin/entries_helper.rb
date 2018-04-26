module Admin::EntriesHelper
  def new_queue_date
    last_in_queue = Entry.queued.last&.publish_date_for_queued || Time.now
    last_in_queue + 1.day
  end

  def share_markdown(entry)
    text = [entry.is_published? ? "[#{entry.plain_title}](#{entry.permalink_url})" : entry.plain_title]
    text << entry.body
    text << entry.combined_tags.map { |t| t.slug.gsub(/-/, '') }.uniq.sort.map { |t| "##{t}" }.join(' ')
    text.reject(&:blank?).join("\n\n")
  end

  def share_title(entry)
    entry.plain_title
  end

  def permalink_date(entry)
    if entry.is_published?
      "#{entry.published_at.strftime('%Y')}/#{entry.published_at.strftime('%-m')}/#{entry.published_at.strftime('%-d')}/#{entry.id}"
    elsif entry.is_queued? && entry.position.present? && entry.id.present?
      "#{entry.publish_date_for_queued.strftime('%Y')}/#{entry.publish_date_for_queued.strftime('%-m')}/#{entry.publish_date_for_queued.strftime('%-d')}/#{entry.id}"
    else
      "#{Time.now.strftime('%Y')}/#{Time.now.strftime('%-m')}/#{Time.now.strftime('%-d')}/1"
    end
  end
end
