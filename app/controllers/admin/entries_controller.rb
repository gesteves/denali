class Admin::EntriesController < AdminController
  include TagList

  before_action :set_entry, only: [:show, :edit, :update, :destroy, :publish, :queue, :draft, :up, :down, :top, :bottom, :preview]
  before_action :get_tags, only: [:new, :edit, :create, :update]
  before_action :load_tags, :load_tagged_entries, only: [:tagged]
  before_action :set_crop_options, only: [:edit, :photo]

  after_action :enqueue_jobs, only: [:create, :publish]
  after_action :update_position, only: [:publish, :queue, :draft, :create]

  skip_before_action :require_login, only: [:preview]

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

  def tagged
    raise ActiveRecord::RecordNotFound if @tags.empty? || @entries.empty?
    @page_title = "Entries tagged \"#{@tag_list.first}\""
  end

  # GET /admin/entries/new
  def new
    @entry = @photoblog.entries.new
    @entry.photos.build
    @page_title = 'New entry'
  end

  # GET /admin/entries/1/edit
  def edit
    @page_title = "Editing “#{@entry.title}”"
  end

  # PATCH /admin/entries/1/publish
  def publish
    notice = @entry.publish ? 'Entry was successfully published.' : 'Entry couldn\'t be published.'
    redirect_entry(@entry, notice)
  end

  # PATCH /admin/entries/1/queue
  def queue
    notice = @entry.queue ? 'Entry was successfully queued.' : 'Entry couldn\'t be queued.'
    redirect_entry(@entry, notice)
  end

  # PATCH /admin/entries/1/draft
  def draft
    notice = @entry.draft ? 'Entry was successfully saved as draft.' : 'Entry couldn\'t be saved as draft.'
    redirect_entry(@entry, notice)
  end

  # POST /admin/entries
  def create
    @entry = Entry.new(entry_params)
    @entry.user = current_user
    @entry.blog = @photoblog
    respond_to do |format|
      if @entry.save
        format.html { redirect_to get_redirect_url(@entry), notice: 'Entry was successfully created.' }
      else
        format.html { render :new }
      end
    end
  end

  # PATCH/PUT /admin/entries/1
  def update
    respond_to do |format|
      if @entry.update(entry_params)
        format.html { redirect_to get_redirect_url(@entry), notice: 'Entry was successfully updated.' }
      else
        format.html { render :edit }
      end
    end
  end

  # DELETE /admin/entries/1
  def destroy
    @entry.destroy
    respond_to do |format|
      format.html { redirect_to request.referrer || admin_entries_path, notice: 'Entry was successfully destroyed.' }
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
    respond_to do |format|
      format.html { render layout: nil }
    end
  end

  def preview
    respond_to do |format|
      format.html {
        if @entry.is_published?
          redirect_to permalink_url @entry
        else
          render 'entries/show', layout: 'application'
        end
      }
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
      params.require(:entry).permit(:title, :body, :slug, :status, :tag_list, :post_to_twitter, :post_to_tumblr, :post_to_flickr, :post_to_500px, :post_to_facebook, :tweet_text, photos_attributes: [:source_url, :source_file, :id, :_destroy, :position, :caption, :crop])
    end

    def enqueue_jobs
      if @entry.is_published? && Rails.env.production?
        IftttJob.perform_later(@entry)
        BufferJob.perform_later(@entry, 'twitter') if @entry.post_to_twitter
        BufferJob.perform_later(@entry, 'facebook') if @entry.post_to_facebook
        TumblrJob.perform_later(@entry) if @entry.post_to_tumblr
        FlickrJob.perform_later(@entry) if @entry.post_to_flickr && @entry.is_photo?
        FiveHundredJob.perform_later(@entry) if @entry.post_to_500px && @entry.is_photo?
      end
    end

    def update_position
      @entry.update_position
    end

    def redirect_entry(entry, notice)
      respond_to do |format|
        format.html { redirect_to get_redirect_url(entry), notice: notice }
      end
    end

    def get_redirect_url(entry)
      if entry.is_published?
        permalink_url(entry)
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

    def set_crop_options
      @crop_options = [
        ['Center', ''],
        ['Detect faces', 'faces'],
        ['Top', 'top'],
        ['Right', 'right'],
        ['Bottom', 'bottom'],
        ['Left', 'left']
      ]
    end

    def respond_to_reposition
      respond_to do |format|
        format.html { redirect_to queued_admin_entries_path }
        format.js { render text: 'ok' }
      end
    end
end
