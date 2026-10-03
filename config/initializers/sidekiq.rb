Sidekiq.configure_server do |config|
  config.redis = {
    url: ENV["REDIS_URL"],
    ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE },
    timeout: 20,
    reconnect_attempts: 3
  }
  # A lambda so the reporter is looked up when a job dies, not autoloaded during boot.
  config.death_handlers << ->(job, exception) { JobDeathReporter.call(job, exception) }
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: ENV["REDIS_URL"],
    ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE },
    timeout: 20,
    reconnect_attempts: 3
  }
end