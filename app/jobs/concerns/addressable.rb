module Addressable
  extend ActiveSupport::Concern

  private
  def permalink_url(entry)
    year, month, day, id, slug = entry.slug_params
    Rails.application.routes.url_helpers.entry_long_url(year, month, day, id, slug, { host: entry.blog.domain })
  end

  def permalink_path(entry)
    year, month, day, id, slug = entry.slug_params
    Rails.application.routes.url_helpers.entry_long_path(year, month, day, id, slug)
  end

  def short_permalink_url(entry)
    Rails.application.routes.url_helpers.entry_url(entry.id, { host: entry.blog.short_domain })
  end
end
