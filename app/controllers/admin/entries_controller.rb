class Admin::EntriesController < AdminController
  include TagList

  before_action :set_entry, only: [:show, :edit, :update, :destroy, :publish, :queue, :draft, :up, :down, :top, :bottom, :more, :share, :instagram, :facebook, :twitter, :geotag, :invalidate, :palette, :annotate, :resize_photos]
  before_action :get_tags, only: [:new, :edit, :create, :update]
  before_action :load_tags, :load_tagged_entries, only: [:tagged]
  before_action :set_redirect_url, only: [:edit, :new, :up, :down, :top, :bottom, :more]
  after_action :update_position, only: [:create]
  after_action :geocode_photos, only: [:create, :update]
  after_action :annotate_photos, only: [:create, :update]
  after_action :update_palette, only: [:create, :update]
  after_action :enqueue_invalidation, only: [:update]

  # GET /admin/entries
  def index
    @page = params[:page] || 1
    @entries = @photoblog.entries.includes(:photos, :tags).published.page(@page)
    @page_title = 'Published'
  end

  # GET /admin/entries/queued
  def queued
    @page = params[:page] || 1
    @entries = @photoblog.entries.includes(:photos, :tags).queued.page(@page)
    @page_title = 'Queued'
  end

  # GET /admin/entries/drafts
  def drafts
    @page = params[:page] || 1
    @entries = @photoblog.entries.includes(:photos, :tags).drafted.page(@page)
    @page_title = 'Drafts'
  end

  # GET /admin/entries/tagged/film
  def tagged
    raise ActiveRecord::RecordNotFound if @tags.empty? || @entries.empty?
    @page_title = "Entries tagged \"#{@tag_list.first}\""
  end

  # GET /admin/entries/new
  def new
    @entry = @photoblog.entries.new
    @entry.status = 'queued'
    @entry.photos.build
    @page_title = 'New entry'
  end

  def search
    raise ActionController::RoutingError unless @photoblog.has_search?
    @page = (params[:page] || 1).to_i
    @count = 10
    @query = params[:q]
    @page_title = "Search"
    if @query.present?
      @page_title = "Search results for \"#{@query}\""
      results = Entry.full_search(@query, @page, @count)
      total_count = results.results.total
      @entries = Kaminari.paginate_array(results.records.includes(:photos), total_count: total_count).page(@page).per(@count)
    end
  end

  # GET /admin/entries/1/edit
  def edit
    @page_title = "Editing “#{@entry.title}”"
    @max_age = ENV['config_entry_caching_minutes'].try(:to_i) || ENV['config_caching_minutes'].try(:to_i) || 5
  end

  def share
    @page_title = "Share “#{@entry.title}”"
    @sizes = [1200]
  end

  # PATCH /admin/entries/1/publish
  def publish
    if @entry.publish
      flash[:notice] = 'Your entry was published!'
    else
      flash[:alert] = 'Your entry couldn’t be published…'
    end
    redirect_to session[:redirect_url] || admin_entries_path
  end

  # PATCH /admin/entries/1/queue
  def queue
    if @entry.queue
      flash[:notice] = 'Your entry was queued!'
    else
      flash[:alert] = 'Your entry couldn’t be queued…'
    end
    redirect_to session[:redirect_url] || admin_entries_path
  end

  # PATCH /admin/entries/1/draft
  def draft
    if @entry.draft
      flash[:notice] = 'Your entry was saved as draft!'
    else
      flash[:alert] = 'Your entry couldn’t be saved as draft…'
    end
    redirect_to session[:redirect_url] || admin_entries_path
  end

  # POST /admin/entries
  def create
    @entry = Entry.new(entry_params)
    @entry.user = current_user
    @entry.blog = @photoblog
    respond_to do |format|
      if @entry.save
        flash[:notice] = 'Your entry was saved!'
        format.html { redirect_to new_admin_entry_path }
      else
        flash[:alert] = 'Your entry couldn’t be saved…'
        format.html { render :new }
      end
    end
  end

  # PATCH/PUT /admin/entries/1
  def update
    respond_to do |format|
      @entry.modified_at = Time.now if @entry.is_published?
      if @entry.update(entry_params)
        logger.info "Entry #{@entry.id} was updated."
        flash[:notice] = 'Your entry was updated!'
        format.html { redirect_to session[:redirect_url] || admin_entries_path }
      else
        flash[:alert] = 'Your entry couldn’t be updated…'
        format.html { render :edit }
      end
    end
  end

  # DELETE /admin/entries/1
  def destroy
    @entry.destroy
    respond_to do |format|
      flash[:notice] = 'Your entry was deleted!'
      format.html { redirect_to admin_entries_path }
    end
  end

  def up
    @entry.move_higher
    respond_to_reposition
  end

  def down
    @entry.move_lower
    respond_to_reposition
  end

  def top
    @entry.move_to_top
    respond_to_reposition
  end

  def bottom
    @entry.move_to_bottom
    respond_to_reposition
  end

  def photo
    @entry = Entry.new
    @count = params[:count] || 1
    @entry.photos.build
    request.format = 'html'
    respond_to do |format|
      format.html { render layout: nil }
    end
  end

  def instagram
    raise ActiveRecord::RecordNotFound unless @entry.is_published? && @entry.is_photo?
    InstagramJob.perform_later(@entry)
    flash[:notice] = 'Your entry was sent to your Instagram queue in Buffer!'
    redirect_to share_admin_entry_path(@entry)
  end

  def twitter
    raise ActiveRecord::RecordNotFound unless @entry.is_published? && @entry.is_photo?
    TwitterJob.perform_later(@entry)
    flash[:notice] = 'Your entry was sent to your Twitter queue in Buffer!'
    redirect_to share_admin_entry_path(@entry)
  end

  def facebook
    raise ActiveRecord::RecordNotFound unless @entry.is_published? && @entry.is_photo?
    FacebookJob.perform_later(@entry)
    flash[:notice] = 'Your entry was sent to your Facebook queue in Buffer!'
    redirect_to share_admin_entry_path(@entry)
  end

  def geotag
    @entry.photos.map(&:geocode)
    flash[:notice] = 'Your entry is currently being geotagged. This may take a minute.'
    redirect_to session[:redirect_url]
  end

  def invalidate
    @entry.touch
    CloudfrontInvalidationJob.perform_later(@entry)
    flash[:notice] = 'Your entry is currently being invalidated in CloudFront. This may take a few minutes.'
    redirect_to session[:redirect_url]
  end

  def palette
    @entry.photos.map(&:update_palette)
    flash[:notice] = 'Your palette is currently being updated. This may take a minute.'
    redirect_to session[:redirect_url]
  end

  def annotate
    @entry.photos.map(&:annotate)
    flash[:notice] = 'Annotation data is currently being updated. This may take a minute.'
    redirect_to session[:redirect_url]
  end

  def resize_photos
    @size = params[:size]
    respond_to do |format|
      format.js
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_entry
      @entry = @photoblog.entries.includes(:photos).find(params[:id])
    end

    def get_tags
      @tags = ActsAsTaggableOn::Tag.order('name asc')
    end

    def entry_params
      params.require(:entry).permit(:title, :body, :slug, :status, :tag_list, :post_to_twitter, :post_to_tumblr, :post_to_flickr, :post_to_instagram, :post_to_facebook, :post_to_pinterest, :tweet_text, :instagram_text, :show_in_map, :invalidate_cloudfront, photos_attributes: [:source_url, :source_file, :id, :_destroy, :position, :caption, :focal_x, :focal_y])
    end

    def update_position
      if !@entry.is_queued?
        @entry.remove_from_list
      end
    end

    def load_tagged_entries
      @page = params[:page] || 1
      @entries = @photoblog.entries.includes(:photos).tagged_with(@tag_list, any: true).order('created_at DESC').page(@page)
    end

    def respond_to_reposition
      respond_to do |format|
        format.html { redirect_to session[:redirect_url] || admin_entries_path }
        format.json {
          response = {
            status: 200,
            entry_id: @entry.id,
            entry_position: @entry.position
          }
          render json: response
        }
      end
    end

    def set_redirect_url
      session[:redirect_url] = request.referer
    end

    def enqueue_invalidation
      CloudfrontInvalidationJob.perform_later(@entry) if entry_params[:invalidate_cloudfront] == "1"
    end

    def geocode_photos
      @entry.photos.map(&:geocode)
    end

    def annotate_photos
      @entry.photos.map(&:annotate)
    end

    def update_palette
      @entry.photos.map(&:update_palette)
    end
end
