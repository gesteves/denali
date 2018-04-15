module AdminHelper
  def icon(text, icon, opts = {})
    opts.reverse_merge!(size: 'is-small', additional_classes: '')
    icon = content_tag :span, class: "icon #{opts[:size]} #{opts[:additional_classes]}" do
      content_tag :i, nil, class: icon
    end
    text = content_tag :span, text
    "#{icon}\n#{text}".html_safe
  end
end
