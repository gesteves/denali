class SitemapsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_max_age
  before_action :set_sitemap_item_count

  def index
    total_entry_pages = (@photoblog.entries.indexable_in_search_engines.count / @items_per_sitemap.to_f).ceil
    @entry_lastmods = @photoblog.entries.indexable_in_search_engines.pluck(:modified_at).each_slice(@items_per_sitemap).map { |page| page.max.strftime('%Y-%m-%dT%H:%M:%S%:z') }
    @entry_pages = [*1..total_entry_pages]

    total_tag_pages = (ActsAsTaggableOn::Tag.all.count / @items_per_sitemap.to_f).ceil
    @tag_pages = [*1..total_tag_pages]

    render format: 'xml'
  end

  def entries
    @page = params[:page]
    @entries = @photoblog.entries.indexable_in_search_engines.page(@page).per(@items_per_sitemap)
    raise ActiveRecord::RecordNotFound if @entries.empty?
    render format: 'xml'
  end

  def tags
    @page = params[:page]
    @tags = ActsAsTaggableOn::Tag.order('name asc').page(@page).per(@items_per_sitemap)
    raise ActiveRecord::RecordNotFound if @tags.empty?
    render format: 'xml'
  end

  private

  def set_sitemap_item_count
    @items_per_sitemap = 1000
  end
end
