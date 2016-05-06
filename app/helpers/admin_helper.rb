module AdminHelper

  def published_count(opts = {})
    render_count Entry.published.size, opts
  end

  def drafts_count(opts = {})
    render_count Entry.drafted.size, opts
  end

  def queued_count(opts = {})
    render_count Entry.queued.size, opts
  end

  def imported_count(opts = {})
    render_count Entry.published.joins(:photos).where('photos.width <= ?', 1280).size, opts
  end

  private
  def render_count(entries, opts = {})
    entries > 0 ? content_tag(:span, "&middot; #{number_with_delimiter entries}".html_safe, opts) : ''
  end
end
