module AdminHelper

  def published_count(opts = {})
    render_count Entry.published.count, opts
  end

  def drafts_count(opts = {})
    render_count Entry.drafted.count, opts
  end

  def queued_count(opts = {})
    render_count Entry.queued.count, opts
  end

  private
  def render_count(entries, opts = {})
    entries > 0 ? content_tag(:span, "&middot; #{number_with_delimiter entries}".html_safe, opts) : ''
  end
end
