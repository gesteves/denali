module AdminHelper
  def icon(text, icon, opts = {})
    opts.reverse_merge!(size: 'is-small', additional_classes: '')
    icon = content_tag :span, class: "icon #{opts[:size]} #{opts[:additional_classes]}" do
      content_tag :i, nil, class: icon
    end
    text = content_tag :span, text
    "#{icon}\n#{text}".html_safe
  end

  def pluralize_with_delimiter(word, count)
    "#{number_with_delimiter count} #{word.pluralize(count)}"
  end

  def bluesky_share_warning_class(entry)
    return "has-text-current" if entry.last_shared_on_bluesky_at.blank?
    months = (ENV['RANDOM_SHARING_MONTHS_THRESHOLD'] || 6).to_i
    months_ago = months.months.ago
    entry.last_shared_on_bluesky_at >= months_ago ? "has-text-danger" : "has-text-current"
  end

  def instagram_share_warning_class(entry)
    return "has-text-current" if entry.last_shared_on_instagram_at.blank?
    months = (ENV['RANDOM_SHARING_MONTHS_THRESHOLD'] || 6).to_i
    months_ago = months.months.ago
    entry.last_shared_on_instagram_at >= months_ago ? "has-text-danger" : "has-text-current"
  end

  def mastodon_share_warning_class(entry)
    return "has-text-current" if entry.last_shared_on_mastodon_at.blank?
    months = (ENV['RANDOM_SHARING_MONTHS_THRESHOLD'] || 6).to_i
    months_ago = months.months.ago
    entry.last_shared_on_mastodon_at >= months_ago ? "has-text-danger" : "has-text-current"
  end
end
