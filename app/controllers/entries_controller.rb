class EntriesController < ApplicationController
  include TagList

  before_action :set_request_format, only: [:index, :tagged, :show]
  before_action :load_tags, only: [:tagged, :tag_feed]
  before_action :set_max_age, only: [:index, :tagged, :search, :sitemap, :sitemap_index, :show, :preview]
  before_action :set_sitemap_entry_count, only: [:sitemap_index, :sitemap]
  skip_before_action :verify_authenticity_token

  def index
    if stale?(@photoblog, public: true)
      @page = (params[:page] || 1).to_i
      @count = @photoblog.posts_per_page
      @entries = @photoblog.entries.includes(:photos).published.photo_entries.page(@page).per(@count)
      raise ActiveRecord::RecordNotFound if @entries.empty? && request.format != 'js'
      begin
        respond_to do |format|
          format.html
          format.json
          format.js { render status: @entries.empty? ? 404 : 200 }
          format.atom { redirect_to @page == 1 ? feed_url(page: nil, format: 'atom') : feed_url(page: @page, format: 'atom'), status: 301 }
        end
      rescue ActionController::UnknownFormat
        if @page == 1
          redirect_to(entries_path, status: 301)
        else
          redirect_to(entries_path(page: @page), status: 301)
        end
      end
    end
  end

  def tagged
    if stale?(@photoblog, public: true)
      @page = (params[:page] || 1).to_i
      @count = @photoblog.posts_per_page
      @entries = @photoblog.entries.includes(:photos).published.photo_entries.tagged_with(@tag_list, any: true).page(@page).per(@count)
      raise ActiveRecord::RecordNotFound if (@tags.empty? || @entries.empty?) && request.format != 'js'
      begin
        respond_to do |format|
          format.html
          format.json
          format.js { render status: @entries.empty? ? 404 : 200 }
          format.atom { redirect_to @page == 1 ? tag_feed_url(tag: @tag_slug, page: nil, format: 'atom') : tag_feed_url(tag: @tag_slug, page: @page, format: 'atom'), status: 301 }
        end
      rescue ActionController::UnknownFormat
        if @page == 1
          redirect_to(tag_path(@tag_slug), status: 301)
        else
          redirect_to(tag_path(tag: @tag_slug, page: @page), status: 301)
        end
      end
    end
  end

  def search
    raise ActionController::RoutingError unless @photoblog.has_search?
    @page = (params[:page] || 1).to_i
    @count = @photoblog.posts_per_page
    @query = params[:q]
    if @query.present?
      results = Entry.published_search(@query, @page, @count)
      total_count = results.results.total
      records = results.records.includes(:photos)
      @entries = Kaminari.paginate_array(records, total_count: total_count).page(@page).per(@count)
    end
    begin
      respond_to do |format|
        format.html
      end
    rescue ActionController::UnknownFormat
      redirect_to search_path, status: 301
    end
  end

  def show
    if stale?(@photoblog, public: true)
      @entry = @photoblog.entries.includes(:photos, :user, :blog, :tags).published.find(params[:id])
      begin
        respond_to do |format|
          format.html {
            redirect_to(@entry.permalink_url, status: 301) unless params_match(@entry, params)
          }
          format.json
        end
      rescue ActionController::UnknownFormat
        redirect_to(@entry.permalink_url, status: 301)
      end
    end
  end

  def photo
    if stale?(@photoblog, public: true)
      entry = @photoblog.entries.joins(:photos).published.where('photos.id = ?', params[:id]).first
      raise ActiveRecord::RecordNotFound if entry.nil?
      redirect_to(entry.permalink_url, status: 301)
    end
  end

  def feed
    if stale?(@photoblog, public: true)
      @page = (params[:page] || 1).to_i
      @count = @photoblog.posts_per_page
      @entries = @photoblog.entries.includes(:photos, :user).published.photo_entries.page(@page).per(@count)
      raise ActiveRecord::RecordNotFound if @entries.empty?
      begin
        respond_to do |format|
          format.atom
          format.json
        end
      rescue ActionController::UnknownFormat
        render text: 'Not found', status: 404
      end
    end
  end

  def tag_feed
    if stale?(@photoblog, public: true)
      @page = (params[:page] || 1).to_i
      @count = @photoblog.posts_per_page
      @entries = @photoblog.entries.includes(:photos, :user).published.photo_entries.tagged_with(@tag_list, any: true).page(@page).per(@count)
      raise ActiveRecord::RecordNotFound if @tags.empty? || @entries.empty?
      begin
        respond_to do |format|
          format.atom
          format.json
        end
      rescue ActionController::UnknownFormat
        render text: 'Not found', status: 404
      end
    end
  end

  def preview
    request.format = 'html'
    if stale?(@photoblog, public: true)
      @entry = @photoblog.entries.includes(:photos, :user, :blog, :tags).where(preview_hash: params[:preview_hash]).limit(1).first
      raise ActiveRecord::RecordNotFound if @entry.nil?
      respond_to do |format|
        format.html {
          if @entry.is_published?
            redirect_to @entry.permalink_url
          else
            render 'entries/show'
          end
        }
      end
    end
  end

  def tumblr
    expires_in 1.year, public: true
    @entry = @photoblog.entries.published.where(tumblr_id: params[:tumblr_id]).order('published_at ASC').first
    respond_to do |format|
      format.html {
        redirect_to @entry.present? ? @entry.permalink_url : root_url, status: 301
      }
    end
  end

  def sitemap_index
    if stale?(@photoblog, public: true)
      @pages = @photoblog.entries.published.page(1).per(@entries_per_sitemap).total_pages
      render format: 'xml'
    end
  end

  def sitemap
    if stale?(@photoblog, public: true)
      @page = params[:page]
      @entries = @photoblog.entries.includes(:photos).published.page(@page).per(@entries_per_sitemap)
      render format: 'xml'
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

  def set_request_format
    request.format = 'json' if request.headers['Content-Type'].try(:downcase) == 'application/vnd.api+json'
  end

  def set_sitemap_entry_count
    @entries_per_sitemap = 100
  end
end
