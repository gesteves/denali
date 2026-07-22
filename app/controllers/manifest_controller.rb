class ManifestController < ApplicationController
  before_action :set_max_age
  before_action -> { set_cache_tags(CacheTags::BLOG) }

  def index
    @icons = [48, 72, 96, 144, 150, 168, 180, 192].map do |s|
      {
        src: @photoblog.touch_icon_url(width: s),
        sizes: "#{s}x#{s}"
      }
    end
  end
end
