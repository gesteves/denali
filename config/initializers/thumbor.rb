require 'ruby-thumbor'

class ThumborUrl
  @@base = Thumbor::CryptoURL.new ENV['thumbor_security_key']
  def self.generate(opts = {})
    if opts[:w]
      opts[:width] = opts.delete(:w).to_i
    end
    if opts[:h]
      opts[:height] = opts.delete(:h).to_i
    end
    Rails.logger.info("thumbor_opts - #{opts.to_json}")
    "https://#{ENV['thumbor_domain']}#{@@base.generate(opts)}"
  end
end
