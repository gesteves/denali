class Admin::EntriesController < AdminController
  include TagList

  before_action :set_entry, only: [:show, :edit, :update, :destroy, :publish, :queue, :draft, :up, :down, :top, :bottom]
  before_action :get_tags, only: [:new, :edit, :create, :update]
  before_action :load_tags, :load_tagged_entries, only: [:tagged]
  after_action :update_position, only: [:create]
  after_action :update_equipment_tags, only: [:create, :update]
  after_action :enqueue_invalidation, only: [:update]

  # GET /admin/entries
  def index
    @page = params[:page] || 1
    @entries = @photoblog.entries.includes(:photos).published.page(@page)
    @page_title = 'Published'
  end

  # GET /admin/entries/queued
  def queued
    @entries = @photoblog.entries.includes(:photos).queued
    @page_title = 'Queued'
  end

  # GET /admin/entries/drafts
  def drafts
    @entries = @photoblog.entries.includes(:photos).drafted
    @page_title = 'Drafts'
  end

  # GET /admin/entries/tagged/film
  def tagged
    raise ActiveRecord::RecordNotFound if @tags.empty? || @entries.empty?
    @page_title = "Entries tagged \"#{@tag_list.first}\""
  end

  def imported
    @page = params[:page] || 1
    @entries = @photoblog.entries.published.joins(:photos).where('photos.width <= ?', 1280).page(@page)
    @page_title = "Imported"
  end

  # GET /admin/entries/new
  def new
    @entry = @photoblog.entries.new
    @entry.status = 'queued'
    @entry.photos.build
    @page_title = 'New entry'
  end

  # GET /admin/entries/1/edit
  def edit
    @page_title = "Editing “#{@entry.title}”"
    @max_age = ENV['config_entry_max_age'].try(:to_i) || 5
  end

  # PATCH /admin/entries/1/publish
  def publish
    if @entry.publish
      flash[:notice] = 'Your entry was published!'
    else
      flash[:alert] = 'Your entry couldn’t be published…'
    end
    redirect_entry
  end

  # PATCH /admin/entries/1/queue
  def queue
    if @entry.queue
      flash[:notice] = 'Your entry was queued!'
    else
      flash[:alert] = 'Your entry couldn’t be queued…'
    end
    redirect_entry
  end

  # PATCH /admin/entries/1/draft
  def draft
    if @entry.draft
      flash[:notice] = 'Your entry was saved as draft!'
    else
      flash[:alert] = 'Your entry couldn’t be saved as draft…'
    end
    redirect_entry
  end

  # POST /admin/entries
  def create
    @entry = Entry.new(entry_params)
    @entry.user = current_user
    @entry.blog = @photoblog
    respond_to do |format|
      if @entry.save
        flash[:notice] = 'Your entry was saved!'
        format.html {
          if params[:return].present?
            redirect_to new_admin_entry_path
          else
            redirect_to get_redirect_url(@entry)
          end
        }
      else
        flash[:alert] = 'Your entry couldn’t be saved…'
        format.html { render :new }
      end
    end
  end

  # PATCH/PUT /admin/entries/1
  def update
    respond_to do |format|
      if @entry.update(entry_params)
        logger.info "Entry #{@entry.id} was updated."
        flash[:notice] = 'Your entry was updated!'
        format.html { redirect_to get_redirect_url(@entry) }
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
      format.html { redirect_to request.referrer || admin_entries_path }
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

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_entry
      @entry = @photoblog.entries.includes(:photos).find(params[:id])
    end

    def get_tags
      @tags = ActsAsTaggableOn::Tag.order('name asc')
    end

    def entry_params
      params.require(:entry).permit(:title, :body, :slug, :status, :tag_list, :post_to_twitter, :post_to_tumblr, :post_to_flickr, :post_to_facebook, :post_to_slack, :post_to_pinterest, :tweet_text, :show_in_map, :invalidate_cloudfront, photos_attributes: [:source_url, :source_file, :id, :_destroy, :position, :caption, :focal_x, :focal_y])
    end

    def update_position
      if !@entry.is_queued?
        @entry.remove_from_list
      end
    end

    def redirect_entry
      respond_to do |format|
        format.html { redirect_to get_redirect_url(@entry)}
      end
    end

    def get_redirect_url(entry)
      if entry.is_published?
        entry.permalink_url
      elsif entry.is_queued?
        queued_admin_entries_path
      else
        drafts_admin_entries_path
      end
    end

    def load_tagged_entries
      @page = params[:page] || 1
      @entries = @photoblog.entries.includes(:photos).tagged_with(@tag_list, any: true).order('created_at DESC').page(@page)
    end

    def respond_to_reposition
      respond_to do |format|
        format.html { redirect_to queued_admin_entries_path }
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

    def enqueue_invalidation
      CloudfrontInvalidationJob.perform_later(@entry) if Rails.env.production? && @entry.is_published? && entry_params[:invalidate_cloudfront] == "1"
    end

    def update_equipment_tags
      tags = []
      @entry.photos.each do |p|
        tags << p.formatted_camera
        tags << p.formatted_film if p.film_make.present? && p.film_type.present?
      end
      @entry.equipment_list = tags
      @entry.save
    end
end
