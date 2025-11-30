elasticsearch_url = ENV['ELASTICSEARCH_URL']
if elasticsearch_url.present?
  Elasticsearch::Model.client = Elasticsearch::Client.new(
    url: elasticsearch_url,
    request_timeout: ENV['ELASTICSEARCH_TIMEOUT'].to_i.positive? ? ENV['ELASTICSEARCH_TIMEOUT'].to_i : 60,
    log: Rails.env.development?
  )
end
