ThumborRails.setup do |config|
  config.server_url = ENV['thumbor_server']
  config.security_key = ENV['thumbor_security_key']
  config.force_no_protocol_in_source_url = true
end
