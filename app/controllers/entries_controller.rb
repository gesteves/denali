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
  end

  def rss
  end
end
