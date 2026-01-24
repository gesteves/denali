if Rails.application.config.public_file_server.enabled
  Rails.application.config.middleware.insert_before ActionDispatch::Static, Rack::Deflater
  Rails.application.config.middleware.insert_before ActionDispatch::Static, Rack::Brotli
end
