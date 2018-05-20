class ServiceWorkerController < ApplicationController
  skip_before_action :verify_authenticity_token

  def index
    expires_in 24.hours, public: true
  end
end
