module Admin::EntriesHelper
  def new_queue_date
    last_in_queue = Entry.queued.last.try(:publish_date_for_queued) || Time.now
    last_in_queue + 1.day
  end

  def share_markdown(entry)
    text = [entry.is_published? ? "[#{entry.plain_title}](#{entry.permalink_url})" : entry.plain_title]
    text << entry.body
    text.reject(&:blank?).join("\n\n")
  end

  def share_title(entry)
    entry.plain_title
  end
end
