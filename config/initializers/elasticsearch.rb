if ENV['ELASTICSEARCH_URL'].present?
  Elasticsearch::Model.client = Elasticsearch::Client.new({
    host: ENV['ELASTICSEARCH_URL'],
    transport_options: {
      request: { timeout: ENV['ELASTICSEARCH_TIMEOUT'].to_i || 1 }
    }
  })
end
