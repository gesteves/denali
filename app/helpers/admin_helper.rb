module AdminHelper

  def published_count(opts = {})
    entries = Entry.published.count
    entries > 0 ? content_tag(:span, "&middot; #{number_with_delimiter entries}".html_safe, opts) : ''
  end

  def drafts_count(opts = {})
    entries = Entry.drafted.count
    entries > 0 ? content_tag(:span, "&middot; #{number_with_delimiter entries}".html_safe, opts) : ''
  end

  def queued_count(opts = {})
    entries = Entry.queued.count
    entries > 0 ? content_tag(:span, "&middot; #{number_with_delimiter entries}".html_safe, opts) : ''
  end
end
