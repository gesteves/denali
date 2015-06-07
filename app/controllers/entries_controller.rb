class EntriesController < ApplicationController
  def index
    @page = params[:page] || 1
    @entries = photoblog.entries.published.page(@page).per(photoblog.posts_per_page)
  end

  def show
    @entry = photoblog.entries.published.find(params[:id])
    respond_to do |format|
      format.html {
        redirect_to permalink(@entry) unless params_match(@entry, params)
      }
    end
  end

  def tumblr
    @entry = photoblog.entries.published.where(tumblr_id: params[:tumblr_id]).order('published_at ASC').first
    respond_to do |format|
      format.html {
        redirect_to permalink(entry)
      }
    end
  end

  def tagged
    tag_list = []
    @page = params[:page] || 1
    @tag_slug = params[:tag]
    @tags = ActsAsTaggableOn::Tag.where(slug: params[:tag])
    @tags.each do |t|
      tag_list << t.name
    end
    if params[:count].nil?
      @entries = photoblog.entries.tagged_with(tag_list, any: true).published.page(@page)
    else
      @entries = photoblog.entries.tagged_with(tag_list, any: true).published.page(@page).per([params[:count].to_i, 20].min)
    end
    respond_to do |format|
      format.html
      format.json
    end
  end

  def rss
    @entries = photoblog.entries.published.page(1)
    render format: 'atom'
  end

  private
  def params_match(entry, params)
    entry_date = entry.published_at
    year = entry_date.strftime('%Y')
    month = entry_date.strftime('%-m')
    day = entry_date.strftime('%-d')
    slug = entry.slug

    year == params[:year] &&
    month == params[:month] &&
    day == params[:day] &&
    slug == params[:slug]
  end
end
