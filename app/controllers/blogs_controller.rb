class BlogsController < ApplicationController
  before_action :set_max_age, except: [:manifest]
  skip_before_action :verify_authenticity_token

  def about
    respond_to do |format|
      format.html {
        add_preload_link_header("https://use.typekit.net/#{ENV['typekit_body_id']}.css", as: 'style') if ENV['typekit_body_id'].present? && @photoblog.about.present?
      }
    end
  end

  def manifest
    expires_in 24.hours, public: true
    @icons = @photoblog.touch_icon.present? ? [128, 152, 144, 192, 512].map { |size| { sizes: "#{size}x#{size}", type: 'image/png', src: @photoblog.touch_icon_url(w: size) } } : []
  end
end
