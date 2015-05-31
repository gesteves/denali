class EntriesController < ApplicationController
  def index
    @page = params[:page] || 1
    @entries = photoblog.entries.published.page(@page)
  end

  def show
    @entry = photoblog.entries.published.find(params[:id])
    respond_to do |format|
      format.html {
        redirect_to entry_path(@entry.id, @entry.slug) if params[:slug] != @entry.slug
      }
    end
  end

  def tumblr
    @entry = photoblog.entries.published.where(tumblr_id: params[:tumblr_id]).order('published_at ASC').first
    respond_to do |format|
      format.html {
        redirect_to entry_path(@entry.id, @entry.slug)
      }
    end
  end

  def tagged
    tag_list = []
    @page = params[:page] || 1
    @tag_slug = params[:tag]
    @tags = ActsAsTaggableOn::Tag.where(slug: params[:tag])
    @tags.each do |t|
      tag_list << t.slug
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
  end
end
