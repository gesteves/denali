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

  def intrinsic_ratio_padding(photo)
    return '' if photo.width.blank? || photo.height.blank?
    padding = (photo.height.to_f/photo.width.to_f) * 100
    "padding-top:#{padding}%".html_safe
  end

  def image_placeholder(photo)
    return '' if photo.color_palette.blank?
    palette = photo.color_palette.split(',').sample(2).join(',')
    "background:linear-gradient(to bottom right, #{palette})".html_safe
  end
end
