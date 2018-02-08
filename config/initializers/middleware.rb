Rails.application.config.middleware.use Rack::Deflater
Rails.application.config.middleware.use HtmlCompressor::Rack, {
  remove_javascript_protocol: false,
  javascript_compressor: Uglifier.new(harmony: true),
  compress_javascript: true,
}
