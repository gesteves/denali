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

  def last_shared_tag(date)
    text = date.blank? ? "Never" : "#{time_ago_in_words(date)} ago"
    months = (ENV['RANDOM_SHARING_MONTHS_THRESHOLD'] || 6).to_i
    months_ago = months.months.ago
    css_class = date.blank? || date < months_ago ? "tag is-success" : "tag is-danger"

    content_tag(:div, class: "tags has-addons") do
      content_tag(:span, "Last shared", class: css_class) + content_tag(:span, text, class: "tag")
    end
  end

  def last_shared_on_bluesky_tag(entry)
    last_shared_tag(entry.last_shared_on_bluesky_at)
  end

  def last_shared_on_mastodon_tag(entry)
    last_shared_tag(entry.last_shared_on_mastodon_at)
  end

  def last_shared_on_instagram_tag(entry)
    last_shared_tag(entry.last_shared_on_instagram_at)
  end
end
