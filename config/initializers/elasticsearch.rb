if ENV['ELASTICSEARCH_URL'].present?
  Elasticsearch::Model.client = Elasticsearch::Client.new({
    host: ENV['ELASTICSEARCH_URL'],
    transport_options: {
      request: { timeout: 1 }
    }
  })
end
