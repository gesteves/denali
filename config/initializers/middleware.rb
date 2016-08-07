uglifier = Uglifier.new output: { comments: :none }

Rails.application.config.middleware.use Rack::Deflater
Rails.application.config.middleware.use HtmlCompressor::Rack, {
  javascript_compressor: uglifier,
  remove_javascript_protocol: false,
  compress_javascript: true,
}
