ThumborRails.setup do |config|
  config.server_url = Rails.application.secrets.thumbor_server
  config.security_key = Rails.application.secrets.thumbor_security_key
  config.force_no_protocol_in_source_url = true
end
