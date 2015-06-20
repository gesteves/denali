module Addressable
  extend ActiveSupport::Concern

  private
  def permalink_url(entry)
    year, month, day, id, slug = entry.slug_params
    Rails.application.routes.url_helpers.entry_long_url(year, month, day, id, slug, { host: entry.blog.domain })
  end

  def permalink_path(entry)
    year, month, day, id, slug = entry.slug_params
    Rails.application.routes.url_helpers.entry_long_path(year, month, day, id)
  end
end
