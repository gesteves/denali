class EntriesController < ApplicationController
  include ActionView::Helpers::NumberHelper
  include TagList

  skip_before_action :verify_authenticity_token
  before_action :load_tags, only: [:tagged, :tag_feed]
  before_action :set_max_age, except: [:amp]
  before_action :set_entry, only: [:show, :amp]

  def index
    @page = (params[:page] || 1).to_i
    @count = @photoblog.posts_per_page
    @entries = @photoblog.entries.includes(photos: [:image_attachment, :image_blob]).published.photo_entries.page(@page).per(@count)
    raise ActiveRecord::RecordNotFound if @entries.empty?
    preconnect_imgix
    preload_fonts
    @srcset = PHOTOS[:entry_list][:srcset]
    @sizes = PHOTOS[:entry_list][:sizes].join(', ')
    @page_url = @page == 1 ? entries_url(page: nil) : entries_url(page: @page)
    @canonical_url = entries_url(page: nil)
    @show_schema = true if @page == 1
    respond_to do |format|
      format.html {
        @page_description = @photoblog.meta_description
        @og_description = @photoblog.plain_tag_line
        @og_title = @photoblog.name
        @feed_url = feed_url(format: 'atom')
        @base_url = entries_url(page: nil).sub(/\/$/, '')
        @heading_title = "Latest entries"
        if @page.nil? || @page == 1
          @page_title = "#{@photoblog.name} – #{@photoblog.plain_tag_line}"
        else
          @page_title = "#{@photoblog.name} – #{@photoblog.plain_tag_line} – Page #{@page}"
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

  def tagged
    @page = (params[:page] || 1).to_i
    @count = @photoblog.posts_per_page
    @entries = @photoblog.entries.includes(photos: [:image_attachment, :image_blob]).published.photo_entries.tagged_with(@tag_list, any: true).page(@page).per(@count)
    raise ActiveRecord::RecordNotFound if @tags.empty? || @entries.empty?
    preconnect_imgix
    preload_fonts
    @srcset = PHOTOS[:entry_list][:srcset]
    @sizes = PHOTOS[:entry_list][:sizes].join(', ')
    @page_url = @page == 1 ? tag_url(tag: @tag_slug, page: nil) : tag_url(@tag_slug, @page)
    @canonical_url = tag_url(tag: @tag_slug, page: nil)
    respond_to do |format|
      format.html {
        @page_description = "Browse all #{number_with_delimiter @tags.first.taggings_count} photos tagged “#{@tags.first.name}” on #{@photoblog.name}."
        @og_description = @page_description
        @og_title = "#{@tags.first.name} on #{@photoblog.name}"
        @feed_url = tag_feed_url(format: 'atom', tag: @tag_slug)
        @base_url = tag_url(tag: @tag_slug, page: nil)
        @heading_title = "Entries tagged “#{@tags.first.name}”"
        @page_title = "#{@tags.first.name} – #{@photoblog.name}"
        @page_title += " – Page #{@page}" unless @page.nil? || @page == 1
        render :index
      }
      format.js { render :index, status: @entries.empty? ? 404 : 200 }
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

  def search
    raise ActionController::RoutingError.new('Not Found') unless @photoblog.show_search? && @photoblog.has_search?
    @page = (params[:page] || 1).to_i
    @count = 48
    @query = params[:q]
    if @query.present?
      @srcset = PHOTOS[:entry_list_square][:srcset]
      @sizes = PHOTOS[:entry_list_square][:sizes].join(', ')
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
    @photos = @entry.photos.includes(:image_attachment, :image_blob, :camera, :lens, :film, :park)
    @srcset = PHOTOS[:entry][:srcset]
    @sizes = PHOTOS[:entry][:sizes].join(', ')
    preconnect_imgix
    preload_fonts
    respond_to do |format|
      format.html {
        redirect_to @entry.permalink_url, status: 301 if request.path != @entry.permalink_path
        @page_title = "#{@entry.plain_title} – #{@photoblog.name}"
      }
      format.all { redirect_to(@entry.permalink_url, status: 301) }
    end
  end

  def amp
    http_cache_forever(public: true) do
      redirect_to(@entry.permalink_url, status: 301)
    end
  end

  def related
    raise ActionController::RoutingError.new('Not Found') unless @photoblog.show_related_entries?
    @srcset = PHOTOS[:entry_list_square][:srcset]
    @sizes = PHOTOS[:entry_list_square][:sizes].join(', ')
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

  def feed
    @count = @photoblog.posts_per_page
    @entries = @photoblog.entries.includes(:user, photos: [:image_attachment, :image_blob, :camera, :lens, :film]).published.photo_entries.page(1).per(@count)
    raise ActiveRecord::RecordNotFound if @entries.empty?
    respond_to do |format|
      format.atom
      format.rss
      format.all { redirect_to feed_url(format: 'atom') }
    end
  end

  def tag_feed
    @count = @photoblog.posts_per_page
    @entries = @photoblog.entries.includes(:user, photos: [:image_attachment, :image_blob, :camera, :lens, :film]).published.photo_entries.tagged_with(@tag_list, any: true).page(1).per(@count)
    raise ActiveRecord::RecordNotFound if @tags.empty? || @entries.empty?
    respond_to do |format|
      format.atom
      format.rss
      format.all { redirect_to tag_feed_url(format: 'atom', tag: @tag_slug) }
    end
  end

  def tumblr
    @entry = @photoblog.entries.published.where(tumblr_id: params[:tumblr_id]).order('published_at ASC').limit(1).first
    raise ActiveRecord::RecordNotFound if @entry.blank?
    respond_to do |format|
      format.all { redirect_to(@entry.permalink_url, status: 301) }
    end
  end

  private

  def set_entry
    @entry = Entry.find_by_url(url: request.path)
  end
end
