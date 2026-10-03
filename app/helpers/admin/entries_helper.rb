module Admin::EntriesHelper
  # A queued entry's publish date is worked out from today's date and the
  # schedule, which no record's updated_at reflects, so any cached fragment
  # that shows one is keyed on them as well.
  def queue_clock
    @queue_clock ||= [
      Time.current.in_time_zone(@photoblog.time_zone).to_date,
      @photoblog.past_publish_schedules_today_count,
      @photoblog.publish_schedules_count
    ]
  end

  # The cache key of an entry card. Also given to the collection renders as
  # `cached:`, so it has to match the partial's own cache call.
  def admin_entry_cache_key(entry)
    entry.is_queued? ? [entry, queue_clock] : entry
  end

  def share_markdown(entry)
    text = []
    text << "[#{entry.plain_title}](#{entry.permalink_url})"
    text << entry.body
    text.reject(&:blank?).join("\n\n")
  end

  def permalink_preview(entry)
    host = Rails.application.routes.default_url_options[:host]
    if entry.id.present?
      "https://#{host}/#{entry.id}/"
    else
      "https://#{host}/#{Entry.count + 1}/"
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
    print_width = size.split('×').map(&:to_f).max
    photo_width = [photo.width, photo.height].map(&:to_f).max
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
