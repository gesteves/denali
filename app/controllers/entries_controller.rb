class EntriesController < ApplicationController

  before_action :domain_redirect
  before_action :load_tags, :load_tagged_entries, only: [:tagged]
  before_action :load_entries, only: [:index]

  def index
    raise ActiveRecord::RecordNotFound if @entries.empty?
    expires_in 60.minutes, :public => true
    respond_to do |format|
      format.html
      format.json
    end
  end

  def show
    @entry = @photoblog.entries.includes(:photos, :user).published.find(params[:id])
    expires_in 60.minutes, :public => true
    respond_to do |format|
      format.html {
        redirect_to(permalink_url(@entry), status: 301) unless params_match(@entry, params)
      }
    end
  end

  def tumblr
    @entry = @photoblog.entries.published.where(tumblr_id: params[:tumblr_id]).order('published_at ASC').first
    raise ActiveRecord::RecordNotFound if @entry.nil?
    respond_to do |format|
      format.html {
        redirect_to permalink_url(@entry), status: 301
      }
    end
  end

  def tagged
    raise ActiveRecord::RecordNotFound if @tags.empty? || @entries.empty?
    expires_in 60.minutes, :public => true
    respond_to do |format|
      format.html
      format.json
    end
  end

  def rss
    @entries = @photoblog.entries.includes(:photos, :user).published.page(1)
    expires_in 60.minutes, :public => true
    render format: 'atom'
  end

  def sitemap
    @entries = @photoblog.entries.includes(:photos).published
    expires_in 24.hours, :public => true
    render format: 'xml'
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

  def load_entries
    @page = params[:page] || 1
    @count = params[:count] || @photoblog.posts_per_page
    @entries = @photoblog.entries.includes(:photos).published.page(@page).per(@count)
  end

  def load_tags
    @tag_slug = params[:tag]
    @tags = ActsAsTaggableOn::Tag.where(slug: params[:tag])
    @tag_list = @tags.map{ |t| t.name }
  end

  def load_tagged_entries
    @page = params[:page] || 1
    @count = params[:count] || @photoblog.posts_per_page
    @entries = @photoblog.entries.includes(:photos).published.tagged_with(@tag_list, any: true).page(@page).per(@count)
  end
end
