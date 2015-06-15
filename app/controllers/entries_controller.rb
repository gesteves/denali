class EntriesController < ApplicationController
  before_filter :redirect_heroku

  def index
    @page = params[:page] || 1
    @entries = @photoblog.entries.published.page(@page).per(@photoblog.posts_per_page)
    expires_in 60.minutes, :public => true
  end

  def show
    @entry = @photoblog.entries.published.find(params[:id])
    expires_in 60.minutes, :public => true
    respond_to do |format|
      format.html {
        redirect_to permalink_url(@entry) unless params_match(@entry, params)
      }
    end
  end

  def tumblr
    @entry = @photoblog.entries.published.where(tumblr_id: params[:tumblr_id]).order('published_at ASC').first
    respond_to do |format|
      format.html {
        redirect_to permalink_url(@entry)
      }
    end
  end

  def tagged
    tag_list = []
    @page = params[:page] || 1
    @count = params[:count]
    @tag_slug = params[:tag]
    @tags = ActsAsTaggableOn::Tag.where(slug: params[:tag])
    raise ActiveRecord::RecordNotFound if @tags.empty?
    @tags.each do |t|
      tag_list << t.name
    end
    if @count.nil?
      @entries = @photoblog.entries.published.tagged_with(tag_list, any: true).page(@page)
    else
      @entries = @photoblog.entries.published.tagged_with(tag_list, any: true).limit(@count)
    end
    expires_in 60.minutes, :public => true
    respond_to do |format|
      format.html
      format.json
    end
  end

  def rss
    @entries = @photoblog.entries.published.page(1)
    expires_in 60.minutes, :public => true
    render format: 'atom'
  end

  def sitemap
    @entries = @photoblog.entries.published
    expires_in 24.hours, :public => true
    render format: 'xml'
  end

  def redirect_heroku
    if Rails.env.production? && request.host.match(/herokuapp\.com/i) && !request.user_agent.match(/cloudfront/i)
      redirect_to "http://#{@photoblog.domain}#{request.fullpath}", status: 301
    end
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
