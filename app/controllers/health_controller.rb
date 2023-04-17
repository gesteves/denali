class HealthController < ApplicationController
  before_action :no_cache
  skip_before_action :domain_redirect

  def show
    render plain: "OK", status: 200
  rescue
    render plain: "Not OK", status: 500
  end
end
