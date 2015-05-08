module AdminHelper

  def drafts_count(opts = {})
    drafts = Entry.drafted.count
    drafts > 0 ? content_tag(:span, "&middot; #{drafts}".html_safe, opts) : ''
  end

  def queued_count(opts = {})
    queued = Entry.queued.count
    queued > 0 ? content_tag(:span, "&middot; #{queued}".html_safe, opts) : ''
  end
end
