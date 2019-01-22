class BlogsController < ApplicationController
  before_action :set_max_age, except: [:manifest]
  skip_before_action :verify_authenticity_token

  def about
    @page_title = "About #{@photoblog.name} · #{@photoblog.tag_line}"
  end

  def manifest
    expires_in 24.hours, public: true
    @icons = @photoblog.touch_icon.attached? ? [128, 152, 144, 192, 512].map { |size| { sizes: "#{size}x#{size}", type: 'image/png', src: @photoblog.touch_icon_url(w: size) } } : []
  end
end
