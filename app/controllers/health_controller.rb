class HealthController < ApplicationController
  before_action :no_cache
  skip_before_action :domain_redirect

  def show
    render plain: "OK", status: :ok
  rescue
    render plain: "Not OK", status: :service_unavailable
  end

  def ready
    ActiveRecord::Base.connection.execute("SELECT 1")
    render plain: "OK", status: :ok
  rescue StandardError
    render plain: "Not OK", status: :service_unavailable
  end
end
