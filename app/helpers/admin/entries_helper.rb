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

  def print_needs_cropping?(photo, size)
    print_height = size.split('×').first.to_f
    print_width = size.split('×').last.to_f
    print_ratio = (print_width/print_height).round(2)
    photo_ratio = if photo.is_horizontal?
      (photo.width.to_f/photo.height.to_f).round(2)
    else
      (photo.height.to_f/photo.width.to_f).round(2)
    end
    photo_ratio != print_ratio
  end

  def print_dpi(photo, size)
    print_width = size.split('×').max.to_f
    photo_width = [photo.width, photo.height].max.to_f
    [300, (photo_width/print_width)].min.floor
  end

  def print_dpi_class(dpi)
    if dpi <= 200
      'is-danger'
    elsif dpi < 300
      'is-warning'
    else
      'is-success'
    end
  end
end
