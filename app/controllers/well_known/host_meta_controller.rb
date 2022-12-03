class WellKnown::HostMetaController < ApplicationController
  before_action :set_max_age

  def show
    render content_type: 'application/xrd+xml', formats: [:xml]
  end
end
