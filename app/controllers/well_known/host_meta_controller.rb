class WellKnown::HostMetaController < ApplicationController
  def show
    render content_type: 'application/xrd+xml', formats: [:xml]
  end
end
