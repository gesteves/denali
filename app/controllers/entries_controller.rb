class EntriesController < ApplicationController
  include TagList

  skip_before_action :verify_authenticity_token
  skip_before_action :set_link_headers, only: [:amp, :show, :preview]
  before_action :set_request_format, only: [:index, :tagged, :show]
  before_action :load_tags, only: [:tagged, :tag_feed]
  before_action :set_max_age, only: [:index, :tagged, :feed, :tag_feed, :search]
  before_action :set_entry_max_age, only: [:show, :preview, :photo, :amp, :related]
  before_action :set_sitemap_entry_count, only: [:sitemap_index, :sitemap]
  before_action :set_entry, only: [:show, :amp]
  before_action :set_preview_entry, only: [:preview]
  before_action :preload_photos, only: [:show, :preview]

  layout 'amp', only: :amp

  def index
    if stale?(@photoblog, public: true)
      @page = (params[:page] || 1).to_i
      @count = @photoblog.posts_per_page
      @entries = @photoblog.entries.includes(photos: [:image_attachment, :image_blob]).published.photo_entries.page(@page).per(@count)
      raise ActiveRecord::RecordNotFound if @page > 1 && @entries.empty? && request.format != 'js'
      respond_to do |format|
        format.html {
          if @page.nil? || @page == 1
            @page_title = "#{@photoblog.name} · #{@photoblog.tag_line}"
          else
            @page_title = "#{@photoblog.name} · Page #{@page}"
          end
        }
        format.json
        format.js { render status: @entries.empty? ? 404 : 200 }
        format.atom { redirect_to feed_url(format: 'atom'), status: 301 }
        format.all {
          if @page == 1
            redirect_to entries_url, status: 301
          else
            redirect_to entries_url(page: @page), status: 301
          end
        }
      end
    end
  end

  def tagged
    if stale?(@photoblog, public: true)
      @page = (params[:page] || 1).to_i
      @count = @photoblog.posts_per_page
      @entries = @photoblog.entries.includes(photos: [:image_attachment, :image_blob]).published.photo_entries.tagged_with(@tag_list, any: true).page(@page).per(@count)
      raise ActiveRecord::RecordNotFound if (@tags.empty? || @entries.empty?) && request.format != 'js'
      respond_to do |format|
        format.html {
          @page_title = "#{@tags.first.name} · #{@photoblog.name}"
          @page_title += " · Page #{@page}" unless @page.nil? || @page == 1
        }
        format.json
        format.js { render status: @entries.empty? ? 404 : 200 }
        format.atom { redirect_to tag_feed_url(tag: @tag_slug, format: 'atom'), status: 301 }
        format.all {
          if @page == 1
            redirect_to tag_url(@tag_slug), status: 301
          else
            redirect_to tag_url(tag: @tag_slug, page: @page), status: 301
          end
        }
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
      records = results.records.includes(photos: [:image_attachment, :image_blob])
      @entries = Kaminari.paginate_array(records, total_count: total_count).page(@page).per(@count)
      @page_title = "Search results for “#{@query}” · #{@photoblog.name}"
      @page_title += " · Page #{@page}" unless @page.nil? || @page == 1
    else
      @page_title = "Search · #{@photoblog.name}"
    end
    respond_to do |format|
      format.html
      format.all { redirect_to search_path, status: 301 }
    end
  end

  def show
    if stale?(@entry, public: true)
      respond_to do |format|
        format.html {
          @page_title = "#{@entry.plain_title} · #{@photoblog.name} · #{@photoblog.tag_line}"
          redirect_to(@entry.permalink_url, status: 301) unless params_match(@entry, params)
        }
        format.json
        format.all { redirect_to(@entry.permalink_url, status: 301) }
      end
    end
  end

  def amp
    if stale?(@photoblog, public: true)
      respond_to do |format|
        format.html {
          @page_title = "#{@entry.plain_title} · #{@photoblog.name} · #{@photoblog.tag_line}"
          redirect_to(@entry.amp_url, status: 301) unless params_match(@entry, params)
        }
      end
    end
  end

  def preview
    if stale?(@entry, public: true)
      respond_to do |format|
        format.html {
          @page_title = "#{@entry.plain_title} · #{@photoblog.name} · #{@photoblog.tag_line}"
          if @entry.is_published?
            redirect_to @entry.permalink_url
          else
            render :show
          end
        }
        format.json {
          if @entry.is_published?
            redirect_to "#{@entry.permalink_url}.json", status: 302
          else
            render :show
          end
        }
      end
    end
  end

  def related
    raise ActionController::RoutingError unless @photoblog.show_related_entries?
    if stale?(@photoblog, public: true)
      @entry = @photoblog.entries.find(params[:id])
      respond_to do |format|
        format.js
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
      @count = @photoblog.posts_per_page
      @entries = @photoblog.entries.includes(:user, photos: [:image_attachment, :image_blob]).published.photo_entries.page(1).per(@count)
      raise ActiveRecord::RecordNotFound if @entries.empty?
      respond_to do |format|
        format.atom
        format.json
        format.all { redirect_to feed_url(format: 'atom') }
      end
    end
  end

  def tag_feed
    if stale?(@photoblog, public: true)
      @count = @photoblog.posts_per_page
      @entries = @photoblog.entries.includes(:user, photos: [:image_attachment, :image_blob]).published.photo_entries.tagged_with(@tag_list, any: true).page(1).per(@count)
      raise ActiveRecord::RecordNotFound if @tags.empty? || @entries.empty?
      respond_to do |format|
        format.atom
        format.json
        format.all { redirect_to tag_feed_url(format: 'atom', tag: @tag_slug) }
      end
    end
  end

  def sitemap_index
    expires_in 24.hours, public: true
    if stale?(@photoblog, public: true)
      @pages = @photoblog.entries.published.page(1).per(@entries_per_sitemap).total_pages
      render format: 'xml'
    end
  end

  def sitemap
    expires_in 24.hours, public: true
    if stale?(@photoblog, public: true)
      @page = params[:page]
      @entries = @photoblog.entries.includes(photos: [:image_attachment, :image_blob]).published.page(@page).per(@entries_per_sitemap)
      render format: 'xml'
    end
  end

  def latest
    expires_in 5.minutes, public: true
    if stale?(@photoblog, public: true)
      @entry = Entry.published.first
      respond_to do |format|
        format.json { redirect_to "#{@entry.permalink_url}.json", status: 302 }
        format.all { redirect_to @entry.permalink_url, status: 302 }
      end
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
    request.format = 'json' if request.headers['Content-Type']&.downcase == 'application/vnd.api+json'
  end

  def set_sitemap_entry_count
    @entries_per_sitemap = 100
  end

  def set_entry
    @entry = @photoblog.entries.published.find(params[:id])
  end

  def set_preview_entry
    @entry = @photoblog.entries.find_by!(preview_hash: params[:preview_hash])
  end

  def preload_photos
    sizes = Photo.sizes('entry')
    @entry.photos.each do |photo|
      src, srcset = photo.srcset('entry')
      add_preload_link_header(src, as: 'image', imagesizes: sizes, imagesrcset: srcset)
    end
  end
end
