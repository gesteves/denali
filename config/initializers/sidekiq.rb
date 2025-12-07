Sidekiq.configure_server do |config|
  config.redis = {
    url: ENV["REDIS_URL"],
    ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE },
    timeout: 20,
    reconnect_attempts: 3,
    pool_size: ENV.fetch("RAILS_MAX_THREADS", 5).to_i + 5
  }
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: ENV["REDIS_URL"],
    ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE },
    timeout: 20,
    reconnect_attempts: 3,
    pool_size: ENV.fetch("RAILS_MAX_THREADS", 5).to_i
  }
end