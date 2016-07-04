Rails.application.config.middleware.use HtmlCompressor::Rack, {
  remove_javascript_protocol: false
}
