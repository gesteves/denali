class BlogsController < ApplicationController
  before_action :set_max_age, except: [:manifest]
  before_action :check_if_user_has_visited, only: [:about]
  skip_before_action :verify_authenticity_token

  def about
    fresh_when @photoblog, public: true
  end

  def manifest
    expires_in 24.hours, public: true
    @icons = @photoblog.touch_icon.present? ? [128, 152, 144, 192].map { |size| { sizes: "#{size}x#{size}", type: 'image/png', src: @photoblog.touch_icon_url(w: size) } } : []
  end
end
