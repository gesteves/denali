Rails.application.config.middleware.use Rack::Deflater
Rails.application.config.middleware.use HtmlCompressor::Rack
