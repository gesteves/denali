class ProgressiveWebAppController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_max_age

  def service_worker
  end

  def manifest
    @icons = @photoblog.touch_icon.present? ? [128, 152, 144, 192].map { |size| { sizes: "#{size}x#{size}", type: 'image/png', src: @photoblog.touch_icon_url(w: size) } } : []
  end

  def offline
  end

  private

  def set_max_age
    expires_in 24.hours, public: true
  end
end
