class HealthController < ApplicationController
  before_action :no_cache
  skip_before_action :verify_authenticity_token
  skip_before_action :domain_redirect

  def show
    render plain: "OK", status: :ok
  rescue ActiveRecord::ConnectionNotEstablished, PG::Error => e
    Rails.logger.error("Health check failed due to database error: #{e.class}: #{e.message}. Exiting to trigger restart.")
    Process.exit(1)
  rescue StandardError => e
    Rails.logger.error("Health check failed: #{e.class}: #{e.message}")
    render plain: "Not OK", status: :service_unavailable
  end
end
