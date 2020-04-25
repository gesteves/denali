class ServiceWorkerController < ApplicationController
  before_action :set_max_age
  skip_before_action :verify_authenticity_token

  def index
  end
end
