class HealthController < ApplicationController
  before_action :no_cache
  skip_before_action :verify_authenticity_token
  skip_before_action :domain_redirect
  # The check runs its own query below; the blog lookup would hit the database
  # outside the rescue and turn a database failure into an error page.
  skip_before_action :set_photoblog, :preload_assets
  skip_around_action :set_time_zone

  def show
    ActiveRecord::Base.with_connection { |connection| connection.select_value('SELECT 1') }
    render plain: "OK", status: :ok
  rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid, PG::Error => e
    Rails.logger.error("Health check failed due to database error: #{e.class}: #{e.message}. Shutting down to trigger restart.")
    # Process.exit here would only end this request's thread. TERM asks Puma to
    # shut down gracefully (finishing this response first), and Fly restarts the
    # machine when the process exits.
    Process.kill('TERM', Process.pid)
    render plain: "Not OK", status: :service_unavailable
  rescue StandardError => e
    Rails.logger.error("Health check failed: #{e.class}: #{e.message}")
    render plain: "Not OK", status: :service_unavailable
  end
end
