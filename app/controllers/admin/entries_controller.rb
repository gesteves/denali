class Admin::EntriesController < AdminController
  include TagList

  before_action :set_entry, only: [:show, :edit, :update, :destroy, :publish, :queue, :draft, :up, :down, :top, :bottom, :share, :crops, :instagram, :facebook, :twitter, :pinterest, :flickr, :tumblr, :invalidate, :refresh_metadata, :resize_photos]
  before_action :get_tags, only: [:new, :edit, :create, :update]
  before_action :load_tags, :load_tagged_entries, only: [:tagged]
  before_action :set_redirect_url, only: [:up, :down, :top, :bottom, :instagram, :facebook, :twitter, :pinterest, :flickr, :tumblr, :invalidate, :refresh_metadata]
  before_action :set_max_age
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

  # GET /admin/entries/:id
  def show
    @page_title = @entry.plain_title
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
      @total_count = results.results.total
      @entries = Kaminari.paginate_array(results.records.includes(:photos), total_count: @total_count).page(@page).per(@count)
    end
  end

  # GET /admin/entries/1/edit
  def edit
    @page_title = "Editing “#{@entry.title}”"
  end

  # PATCH /admin/entries/1/publish
  def publish
    if @entry.publish
      flash[:success] = 'Your entry was published!'
    else
      flash[:warning] = 'Your entry couldn’t be published…'
    end
    redirect_to admin_entries_path
  end

  # PATCH /admin/entries/1/queue
  def queue
    if @entry.queue
      flash[:success] = 'Your entry was sent to the queue.'
    else
      flash[:warning] = 'Your entry couldn’t be queued…'
    end
    redirect_to queued_admin_entries_path
  end

  # PATCH /admin/entries/1/draft
  def draft
    if @entry.draft
      flash[:success] = 'Your entry was moved to the drafts.'
    else
      flash[:warning] = 'Your entry couldn’t be moved to the drafts…'
    end
    redirect_to drafts_admin_entries_path
  end

  # POST /admin/entries
  def create
    @entry = Entry.new(entry_params)
    @entry.user = current_user
    @entry.blog = @photoblog
    respond_to do |format|
      if @entry.save
        flash[:success] = "Your new entry was saved! <a href=\"#{admin_entry_path(@entry)}\">Check it out.</a>"
        format.html { redirect_to new_admin_entry_path }
      else
        flash[:warning] = 'Your entry couldn’t be saved…'
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
        flash[:success] = 'Your entry has been updated!'
        format.html { redirect_to session[:redirect_url] || admin_entry_path(@entry) }
      else
        flash[:warning] = 'Your entry couldn’t be updated…'
        format.html { render :edit }
      end
    end
  end

  # DELETE /admin/entries/1
  def destroy
    @entry.destroy
    respond_to do |format|
      flash[:danger] = 'Your entry was deleted forever.'
      format.html { redirect_to session[:redirect_url] || admin_entries_path }
    end
  end

  def up
    @entry.move_higher
    flash[:success] = 'Your entry was moved up in the queue.'
    respond_to_reposition
  end

  def down
    @entry.move_lower
    flash[:success] = 'Your entry was moved down in the queue.'
    respond_to_reposition
  end

  def top
    @entry.move_to_top
    flash[:success] = 'Your entry was moved to the top of the queue.'
    respond_to_reposition
  end

  def bottom
    @entry.move_to_bottom
    flash[:success] = 'Your entry was moved to the bottom of the queue.'
    respond_to_reposition
  end

  def organize_queue
    @entries = @photoblog.entries.includes(:photos).queued
    @page_title = 'Organize queue'
  end

  def update_queue
    entry_ids = params[:entry_ids]
    entries = Entry.where(id: entry_ids)
    position = 1
    entry_ids.each do |id|
      entry = entries.find { |e| e.id == id }
      if entry.is_queued?
        entry.position = position
        entry.save
        position += 1
      end
    end
    respond_to do |format|
      format.json
    end
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

  def share
    respond_to do |format|
      format.html {
        if params[:modal]
          render layout: nil
        else
          render
        end
      }
    end
  end

  def crops
    @sizes = {
      'Sizes': [
        ['Thumbnail 100', 100],
        ['Small 240', 240],
        ['Small 320', 320],
        ['Medium 500', 500],
        ['Medium 640', 640],
        ['Medium 800', 800],
        ['Large 1024', 1024],
        ['Large 1200', 1200],
        ['Large 1600', 1600],
        ['Large 2048', 2048],
        ['Original', 'original']
      ],
      'Instagram': [['Feed', 'instagram_feed'], ['Story', 'instagram_story']]
    }
    respond_to do |format|
      format.html {
        if params[:modal]
          render layout: nil
        else
          render
        end
      }
    end
  end

  def instagram
    raise ActiveRecord::RecordNotFound unless @entry.is_published? && @entry.is_photo?
    InstagramJob.perform_later(@entry)
    @message = 'Your entry was sent to your Instagram queue in Buffer.'
    respond_to do |format|
      format.html {
        flash[:success] = @message
        redirect_to session[:redirect_url] || admin_entry_path(@entry)
      }
      format.js { render :notify }
    end
  end

  def twitter
    raise ActiveRecord::RecordNotFound unless @entry.is_published? && @entry.is_photo?
    TwitterJob.perform_later(@entry)
    @message = 'Your entry was sent to your Twitter queue in Buffer.'
    respond_to do |format|
      format.html {
        flash[:success] = @message
        redirect_to session[:redirect_url] || admin_entry_path(@entry)
      }
      format.js { render :notify }
    end
  end

  def facebook
    raise ActiveRecord::RecordNotFound unless @entry.is_published? && @entry.is_photo?
    FacebookJob.perform_later(@entry)
    @message = 'Your entry was sent to your Facebook queue in Buffer.'
    respond_to do |format|
      format.html {
        flash[:success] = @message
        redirect_to session[:redirect_url] || admin_entry_path(@entry)
      }
      format.js { render :notify }
    end
  end

  def pinterest
    raise ActiveRecord::RecordNotFound unless @entry.is_published? && @entry.is_photo?
    PinterestJob.perform_later(@entry)
    @message = 'Your entry was sent to Pinterest.'
    respond_to do |format|
      format.html {
        flash[:success] = @message
        redirect_to session[:redirect_url] || admin_entry_path(@entry)
      }
      format.js { render :notify }
    end
  end

  def flickr
    raise ActiveRecord::RecordNotFound unless @entry.is_published? && @entry.is_photo?
    FlickrJob.perform_later(@entry)
    @message = 'Your entry was sent to Flickr.'
    respond_to do |format|
      format.html {
        flash[:success] = @message
        redirect_to session[:redirect_url] || admin_entry_path(@entry)
      }
      format.js { render :notify }
    end
  end

  def tumblr
    raise ActiveRecord::RecordNotFound unless @entry.is_published? && @entry.is_photo?
    TumblrJob.perform_later(@entry)
    @message = 'Your entry was sent to your Tumblr queue.'
    respond_to do |format|
      format.html {
        flash[:success] = @message
        redirect_to session[:redirect_url] || admin_entry_path(@entry)
      }
      format.js { render :notify }
    end
  end

  def invalidate
    @entry.touch
    CloudfrontInvalidationJob.perform_later(@entry)
    @message = 'Your entry is being cleared from cache. This may take a few moments.'
    respond_to do |format|
      format.html {
        flash[:success] = @message
        redirect_to session[:redirect_url] || admin_entry_path(@entry)
      }
      format.js { render :notify }
    end
  end

  def refresh_metadata
    @entry.photos.map(&:geocode)
    @entry.photos.map(&:annotate)
    @entry.photos.map(&:update_palette)
    CloudfrontInvalidationJob.perform_later(@entry)
    @message = 'Your entry’s metadata is being updated. This may take a few moments.'
    respond_to do |format|
      format.html {
        flash[:success] = @message
        redirect_to session[:redirect_url] || admin_entry_path(@entry)
      }
      format.js { render :notify }
    end
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
        format.html { redirect_to session[:redirect_url] || admin_entry_path(@entry) }
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

    def set_max_age
      @max_age = ENV['config_entry_caching_minutes'].try(:to_i) || ENV['config_caching_minutes'].try(:to_i) || 5
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
