module Thumborizable
  extend ActiveSupport::Concern

  def thumbor_url(opts = {})
    return if self&.image&.key.blank?
    opts.merge!(image: "#{ENV['S3_BUCKET']}/#{self.image.key}")
    path = Thumbor.generate(opts)
    "https://#{ENV['THUMBOR_DOMAIN']}/thumbor#{path}"
  end
end
