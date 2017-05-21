class ProgressiveWebAppController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_max_age

  def service_worker
  end

  def manifest
  end

  def offline
  end

  private

  def set_max_age
    expires_in 24.hours, public: true
  end
end
