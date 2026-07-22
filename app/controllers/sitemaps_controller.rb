class SitemapsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_max_age
  before_action :set_sitemap_item_count
  before_action -> { set_cache_tags(CacheTags::ENTRIES) }

  def index
    modified_dates = @photoblog.entries.indexable_in_search_engines.pluck(:modified_at)
    @entry_lastmods = modified_dates.each_slice(@items_per_sitemap).map { |page| page.max.strftime('%Y-%m-%dT%H:%M:%S%:z') }
    @entry_pages = [*1..@entry_lastmods.length]

    render format: 'xml'
  end

  def entries
    @page = params[:page]
    @entries = @photoblog.entries
                         .indexable_in_search_engines
                         .includes(photos: :image_attachment)
                         .page(@page)
                         .per(@items_per_sitemap)
    raise ActiveRecord::RecordNotFound if @entries.empty?
    render format: 'xml'
  end

  private

  def set_sitemap_item_count
    @items_per_sitemap = 1000
  end
end
