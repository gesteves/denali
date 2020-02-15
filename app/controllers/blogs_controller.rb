class BlogsController < ApplicationController
  before_action :set_max_age, except: [:manifest]
  skip_before_action :verify_authenticity_token

  def about
    if stale?(@photoblog, public: true)
      @page_title = "About · #{@photoblog.name} · #{@photoblog.tag_line}"
      respond_to do |format|
        format.html
      end
    end
  end

  def manifest
    expires_in 1.month, public: true
    if stale?(@photoblog, public: true)
      @icons = @photoblog.touch_icon.attached? ? [128, 152, 144, 192, 512].map { |size| { sizes: "#{size}x#{size}", type: 'image/png', src: @photoblog.touch_icon_url(w: size) } } : []
      respond_to do |format|
        format.json
      end
    end
  end
end
