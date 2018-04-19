module Admin::EntriesHelper
  def new_queue_date
    last_in_queue = Entry.queued.last.try(:publish_date_for_queued) || Time.now
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

  def image_ratio_class(photo)
    image_ratio = (photo.width.to_f / photo.height.to_f).round(2)
    ratio = %w{
      1by1
      1by2
      1by3
      2by1
      2by3
      3by1
      3by2
      3by4
      3by5
      4by3
      4by5
      5by3
      5by4
      16by9
      9by16
    }.find { |i| (i.split('by').first.to_f / i.split('by').last.to_f).round(2) == image_ratio }
    ratio.nil? ? '' : "is-#{ratio}"
  end
end
