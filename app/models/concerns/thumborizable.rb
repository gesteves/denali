module Thumborizable
  extend ActiveSupport::Concern

  def thumbor_url(key, opts = {})
    return if key.blank?
    opts.merge!(image: "#{ENV['S3_BUCKET']}/#{key}")
    path = Thumbor.generate(opts)
    "https://#{ENV['THUMBOR_DOMAIN']}/thumbor#{path}"
  end
end
