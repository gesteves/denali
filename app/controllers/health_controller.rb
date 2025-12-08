class HealthController < ApplicationController
  before_action :no_cache
  skip_before_action :domain_redirect, :get_photoblog

  def show
    # Check database connection
    ActiveRecord::Base.connection.execute("SELECT 1")

    # Check Elasticsearch connection
    if ENV['ELASTICSEARCH_URL'].present?
      Elasticsearch::Model.client.ping
    end

    # Check Sidekiq Redis connection
    if ENV["REDIS_URL"].present?
      Sidekiq.redis(&:ping)
    end

    # Check Cache Redis connection
    if ENV["REDIS_CACHE_URL"].present?
      Rails.cache.redis.with(&:ping)
    end

    render plain: "OK", status: :ok
  rescue StandardError => e
    Rails.logger.error("Health check failed: #{e.class}: #{e.message}")
    render plain: "Not OK", status: :service_unavailable
  end
end
