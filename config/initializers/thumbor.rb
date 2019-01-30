require 'ruby-thumbor'

class ThumborUrl
  @@base = Thumbor::CryptoURL.new ENV['thumbor_security_key']
  def self.generate(opts = {})
    if opts[:w]
      opts[:width] = opts.delete(:w)
    end
    if opts[:h]
      opts[:height] = opts.delete(:h)
    end
    "https://#{ENV['thumbor_domain']}#{@@base.generate(opts)}"
  end
end
