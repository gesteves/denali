require 'net/http'
class YoJob < ActiveJob::Base

  queue_as :default

  def perform(entry)
    Net::HTTP.post_form(URI.parse('https://api.justyo.co/yoall/'), { api_token: ENV['yo_api_token'], link: permalink_url(entry) })
  end

  def permalink_url(entry)
    year, month, day, id, slug = entry.slug_params
    Rails.application.routes.url_helpers.entry_long_url(year, month, day, id, slug, { host: entry.blog.domain })
  end
end
