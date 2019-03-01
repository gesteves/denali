elasticsearch_url = ENV['ELASTICSEARCH_URL'] || ENV['SEARCHBOX_URL']
if elasticsearch_url.present?
  Elasticsearch::Model.client = Elasticsearch::Client.new({
    host: elasticsearch_url,
    transport_options: {
      request: { timeout: ENV['ELASTICSEARCH_TIMEOUT'].to_i || 1 }
    }
  })
end
