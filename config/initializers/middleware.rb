Rails.application.config.middleware.insert_before ActionDispatch::Static, Rack::Deflater
Rails.application.config.middleware.insert_before ActionDispatch::Static, Rack::Brotli
