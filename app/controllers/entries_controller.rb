class EntriesController < ApplicationController
  include TagList

  skip_before_action :verify_authenticity_token
  before_action :load_tags, only: [:tagged, :tag_feed]
  before_action :set_max_age, except: [:amp, :related]
  before_action -> { set_max_age(minutes: 1440) }, only: [:related]
  before_action :set_sitemap_entry_count, only: [:sitemap_index, :sitemap]
  before_action :set_entry, only: [:show, :amp]

  def index
    @page = (params[:page] || 1).to_i
    @count = @photoblog.posts_per_page
    @entries = @photoblog.entries.includes(photos: [:image_attachment, :image_blob]).published.photo_entries.page(@page).per(@count)
    raise ActiveRecord::RecordNotFound if @page > 1 && @entries.empty? && request.format != 'js'
    if stale?(@entries, public: true)
      set_link_headers
      respond_to do |format|
        format.html {
          if @page.nil? || @page == 1
            @page_title = @photoblog.name
          else
            @page_title = "#{@photoblog.name} – Page #{@page}"
          end
        }
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
    @page = (params[:page] || 1).to_i
    @count = @photoblog.posts_per_page
    @entries = @photoblog.entries.includes(photos: [:image_attachment, :image_blob]).published.photo_entries.tagged_with(@tag_list, any: true).page(@page).per(@count)
    raise ActiveRecord::RecordNotFound if (@tags.empty? || @entries.empty?) && request.format != 'js'
    if stale?(@entries, public: true)
      set_link_headers
      respond_to do |format|
        format.html {
          @page_title = "#{@tags.first.name} – #{@photoblog.name}"
          @page_title += " – Page #{@page}" unless @page.nil? || @page == 1
        }
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
    raise ActionController::RoutingError.new('Not Found') unless @photoblog.has_search?
    @page = (params[:page] || 1).to_i
    @count = 48
    @query = params[:q]
    if @query.present?
      results = Entry.published_search(@query, @page, @count)
      total_count = results.results.total
      records = results.records.includes(photos: [:image_attachment, :image_blob])
      @entries = Kaminari.paginate_array(records, total_count: total_count).page(@page).per(@count)
      @page_title = "Search results for “#{@query}” – #{@photoblog.name}"
      @page_title += " – Page #{@page}" unless @page.nil? || @page == 1
    else
      @page_title = "Search – #{@photoblog.name}"
    end
    respond_to do |format|
      format.html
      format.all { redirect_to search_path, status: 301 }
    end
  end

  def show
    if stale?(@entry, public: true)
      preload_photos
      respond_to do |format|
        format.html {
          redirect_to @entry.permalink_url, status: 301 if request.path != @entry.permalink_path
          @page_title = "#{@entry.plain_title} – #{@photoblog.name}"
        }
        format.all { redirect_to(@entry.permalink_url, status: 301) }
      end
    end
  end

  def amp
    http_cache_forever(public: true) do
      redirect_to(@entry.permalink_url, status: 301)
    end
  end

  def related
    raise ActionController::RoutingError.new('Not Found') unless @photoblog.show_related_entries?
    if stale?(@photoblog, public: true)
      @entry = if params[:id].present?
       @photoblog.entries.published.find(params[:id])
      elsif params[:preview_hash].present?
        @photoblog.entries.find_by!(preview_hash: params[:preview_hash])
      end
      respond_to do |format|
        format.js {
          redirect_to related_url(@entry, format: 'js'), status: 301 if params[:preview_hash].present? && @entry.is_published?
        }
      end
    end
  end

  def feed
    @count = @photoblog.posts_per_page
    @entries = @photoblog.entries.includes(:user, photos: [:image_attachment, :image_blob]).published.photo_entries.page(1).per(@count)
    raise ActiveRecord::RecordNotFound if @entries.empty?
    if stale?(@entries, public: true)
      respond_to do |format|
        format.atom
        format.json
        format.rss
        format.all { redirect_to feed_url(format: 'atom') }
      end
    end
  end

  def tag_feed
    @count = @photoblog.posts_per_page
    @entries = @photoblog.entries.includes(:user, photos: [:image_attachment, :image_blob]).published.photo_entries.tagged_with(@tag_list, any: true).page(1).per(@count)
    raise ActiveRecord::RecordNotFound if @tags.empty? || @entries.empty?
    if stale?(@entries, public: true)
      respond_to do |format|
        format.atom
        format.json
        format.rss
        format.all { redirect_to tag_feed_url(format: 'atom', tag: @tag_slug) }
      end
    end
  end

  def sitemap_index
    if stale?(@photoblog, public: true)
      @pages = @photoblog.entries.published('published_at ASC').page(1).per(@entries_per_sitemap).total_pages
      render format: 'xml'
    end
  end

  def sitemap
    @page = params[:page]
    @entries = @photoblog.entries.includes(photos: [:image_attachment, :image_blob]).published('published_at ASC').page(@page).per(@entries_per_sitemap)
    if stale?(etag: @entries, last_modified: @entries.map(&:updated_at).max, public: true)
      render format: 'xml'
    end
  end

  def tumblr
    @entry = @photoblog.entries.published.where(tumblr_id: params[:tumblr_id]).order('published_at ASC').limit(1).first
    raise ActiveRecord::RecordNotFound if @entry.blank?
    if stale?(@entry, public: true)
      respond_to do |format|
        format.all { redirect_to(@entry.permalink_url, status: 301) }
      end
    end
  end

  private

  def set_sitemap_entry_count
    @entries_per_sitemap = 100
  end

  def set_entry
    @entry = Entry.find_by_url(url: request.path)
  end

  def preload_photos
    sizes = Photo.sizes('entry')
    @entry.photos.each do |photo|
      src, srcset = photo.srcset('entry')
      add_preload_link_header(src, as: 'image', imagesizes: sizes, imagesrcset: srcset)
    end
  end

  def set_link_headers
    if request.format.html?
      ENV['imgix_domain'].split(',').each do |domain|
        add_preconnect_link_header("http#{'s' if ENV['imgix_secure'].present?}://#{domain}")
      end
    end
  end
end
