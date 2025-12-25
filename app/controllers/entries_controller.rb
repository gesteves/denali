class EntriesController < ApplicationController
  include ActionView::Helpers::NumberHelper
  include TagList

  skip_before_action :verify_authenticity_token
  before_action :load_tags, only: [:tagged, :tag_feed]
  before_action :set_max_age, except: [:amp, :short, :random]
  before_action :set_entry, only: [:show, :amp]

  def index
    @page = (params[:page] || 1).to_i
    @count = @photoblog.posts_per_page
    @entries = @photoblog.entries.includes(photos: [:image_attachment, :image_blob, :crops, :territories]).published.photo_entries.page(@page).per(@count)
    raise ActiveRecord::RecordNotFound if @entries.empty?
    preload_fonts
    @srcset = PHOTOS[:entry_list][:srcset]
    @sizes = PHOTOS[:entry_list][:sizes].join(', ')
    @page_url = @page == 1 ? entries_url(page: nil) : entries_url(page: @page)
    @canonical_url = entries_url(page: nil)
    respond_to do |format|
      format.html {
        @page_description = @photoblog.meta_description
        @og_description = I18n.t('blog.tag_line')
        @og_title = @photoblog.name
        @feed_url = feed_url(format: 'atom')
        @base_url = entries_url(page: nil).sub(/\/$/, '')
        @heading_title = "Latest photos"
        @hide_title = true
        if @page.nil? || @page == 1
          @page_title = "#{@photoblog.name} – #{I18n.t('blog.tag_line')}"
          @show_schema = true
        else
          @page_title = "#{@photoblog.name} – #{I18n.t('blog.tag_line')} – Page #{@page}"
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
    @entries = @photoblog.entries.includes(photos: [:image_attachment, :image_blob, :crops]).published.photo_entries.tagged_with(@tag_list, any: true).page(@page).per(@count)
    raise ActiveRecord::RecordNotFound if @tags.empty? || @entries.empty?
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
        @heading_title = "Photos tagged “#{@tags.first.name}”"
        @page_title = "#{@tags.first.name} – #{@photoblog.name}"
        @page_title += " – Page #{@page}" unless @page.nil? || @page == 1
        @suggested_tags = ActsAsTaggableOn::Tag.related_to(@tags.first, limit: 20)
        @suggested_tags_title = "You may also like these tags."
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
    @count = @photoblog.posts_per_page
    @query = params[:q]
    @suggested_tags = []

    if @query.present?
      @srcset = PHOTOS[:entry_list][:srcset]
      @sizes = PHOTOS[:entry_list][:sizes].join(', ')

      search_results = Entry.search_with_tag_suggestions(@query, @page, @count)
      results = search_results[:entries]

      total_count = results.results.total
      # Preserve Elasticsearch score order by fetching IDs first, then reordering
      hit_ids = results.response.hits.hits.map { |h| h._id.to_i }
      records_by_id = Entry.includes(photos: [:image_attachment, :image_blob, :crops, :territories]).where(id: hit_ids).index_by(&:id)
      ordered_records = hit_ids.map { |id| records_by_id[id] }.compact
      @entries = Kaminari.paginate_array(ordered_records, total_count: total_count).page(@page).per(@count)

      # Suggest tags based on whether we have results or not
      if @entries.present?
        # We have results: show tags from the search results, fall back to recently used
        @suggested_tags = search_results[:suggested_tags].presence || ActsAsTaggableOn::Tag.most_recently_used(limit: 20)
      else
        # No results: try to match tags based on the query to help users find content
        @suggested_tags = ActsAsTaggableOn::Tag.matching(@query, limit: 20).presence || ActsAsTaggableOn::Tag.most_recently_used(limit: 20)
      end

      @page_title = "Search results for “#{@query}” – #{@photoblog.name}"
      @page_title += " – Page #{@page}" unless @page.nil? || @page == 1
      @page_url = @page == 1 ? search_url(q: @query) : search_url(q: @query, page: @page)
      @base_url = search_url(q: @query)
      @heading_title = "Search Results"
      respond_to do |format|
        format.html
        format.js { render status: @entries.empty? ? 404 : 200 }
        format.all { redirect_to search_path, status: 301 }
      end
    else
      @page_title = "Search – #{@photoblog.name}"
      @suggested_tags = ActsAsTaggableOn::Tag.most_recently_used(limit: 20)
      respond_to do |format|
        format.html
        format.all { redirect_to search_path, status: 301 }
      end
    end
  end

  def show
    # Preload all associations in a single call to minimize queries
    ActiveRecord::Associations::Preloader.new(
      records: [@entry],
      associations: [
        :user,
        { taggings: :tag },
        { photos: [:image_attachment, :image_blob, :camera, :lens, :film, :park, :crops, :territories] }
      ]
    ).call
    @photos = @entry.photos
    @srcset = PHOTOS[:entry][:srcset]
    @src = PHOTOS[:entry][:src]
    @sizes = PHOTOS[:entry][:sizes].join(', ')
    preload_fonts
    respond_to do |format|
      format.html {
        redirect_to @entry.permalink_url, status: 301 if request.path != @entry.permalink_path
        @page_title = "#{@entry.plain_title} – #{@photoblog.name}"
        @has_territories = @entry.photos.any? { |p| p.territories.present? }
      }
      format.all { redirect_to(@entry.permalink_url, status: 301) }
    end
  end

  def short
    entry_id = params[:id].to_i(36)
    entry = Entry.find(entry_id)
    http_cache_forever(public: true) do
      redirect_to entry.permalink_url, status: 301
    end
  end

  def random
    entry = Entry.find(Entry.published.where('published_at >= ?', 4.years.ago).pluck(:id).sample)
    response.headers['Cache-Control'] = "s-maxage=1, max-age=0, public"
    redirect_to entry.permalink_url, status: 302
  end

  def amp
    http_cache_forever(public: true) do
      redirect_to(@entry.permalink_url, status: 301)
    end
  end

  def feed
    @count = @photoblog.posts_per_page
    @entries = @photoblog.entries.includes(:user, taggings: :tag, photos: [:image_attachment, :image_blob, :camera, :lens, :film, :territories]).published.photo_entries.page(1).per(@count)
    raise ActiveRecord::RecordNotFound if @entries.empty?
    respond_to do |format|
      format.atom
      format.rss
      format.all { redirect_to feed_url(format: 'atom') }
    end
  end

  def tag_feed
    @count = @photoblog.posts_per_page
    @entries = @photoblog.entries.includes(:user, taggings: :tag, photos: [:image_attachment, :image_blob, :camera, :lens, :film, :territories]).published.photo_entries.tagged_with(@tag_list, any: true).page(1).per(@count)
    raise ActiveRecord::RecordNotFound if @tags.empty? || @entries.empty?
    respond_to do |format|
      format.atom
      format.rss
      format.all { redirect_to tag_feed_url(format: 'atom', tag: @tag_slug) }
    end
  end

  private

  def set_entry
    @entry = Entry.find_by_url(url: request.path)
  end
end
