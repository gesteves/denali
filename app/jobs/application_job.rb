class ApplicationJob < ActiveJob::Base
  include ActionView::Helpers::TextHelper

  def permalink_url(entry)
    year, month, day, id, slug = entry.slug_params
    protocol = Rails.configuration.force_ssl ? 'https' : 'http'
    Rails.application.routes.url_helpers.entry_long_url(year, month, day, id, slug, { host: entry.blog.domain, protocol: protocol })
  end

  def permalink_path(entry)
    year, month, day, id, slug = entry.slug_params
    Rails.application.routes.url_helpers.entry_long_path(year, month, day, id, slug)
  end
end
