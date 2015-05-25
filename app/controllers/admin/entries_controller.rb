class Admin::EntriesController < AdminController
  before_action :set_entry, only: [:show, :edit, :update, :destroy, :publish, :queue, :draft]
  before_action :get_tags, only: [:new, :edit, :create, :update]

  # GET /admin/entries
  def index
    @entries = Entry.published
    @page_title = 'Published'
  end

  # GET /admin/entries/queued
  def queued
    @entries = Entry.queued
    @page_title = 'Queued'
  end

  # GET /admin/entries/drafts
  def drafts
    @entries = Entry.drafted
    @page_title = 'Drafts'
  end

  # GET /admin/entries/new
  def new
    @entry = Entry.new
    @entry.photos.build
    @page_title = 'New entry'
  end

  # GET /admin/entries/1/edit
  def edit
    @page_title = "Editing “#{@entry.title}”"
  end

  # PATCH /admin/entries/1/publish
  def publish
    if @entry.publish && @entry.update_position
      respond_to do |format|
        format.html { redirect_to admin_entries_path, notice: 'Entry was successfully published.' }
      end
    else
      respond_to do |format|
        format.html { redirect_to request.referrer, notice: 'Entry couldn\'t be published.' }
      end
    end
  end

  # PATCH /admin/entries/1/queue
  def queue
    if @entry.queue && @entry.update_position
      respond_to do |format|
        format.html { redirect_to request.referrer, notice: 'Entry was successfully queued.' }
      end
    else
      respond_to do |format|
        format.html { redirect_to request.referrer, notice: 'Entry couldn\'t be queued.' }
      end
    end
  end

  # PATCH /admin/entries/1/draft
  def draft
    if @entry.draft && @entry.update_position
      respond_to do |format|
        format.html { redirect_to request.referrer, notice: 'Entry was successfully saved to drafts.' }
      end
    else
      respond_to do |format|
        format.html { redirect_to request.referrer, notice: 'Entry couldn\'t be saved to drafts.' }
      end
    end
  end

  # POST /admin/entries
  def create
    @entry = Entry.new(entry_params)
    @entry.user = current_user
    @entry.blog = photoblog
    respond_to do |format|
      if @entry.save && @entry.update_position
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

  def reposition
    @entry = Entry.find(params[:id])
    @entry.insert_at(params[:position].to_i)
    respond_to do |format|
      format.js { render text: 'ok' }
    end
  end

  def photo
    @entry = Entry.new
    @count = params[:count] || 1
    @entry.photos.build
    respond_to do |format|
      format.html { render layout: nil }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_entry
      @entry = Entry.find(params[:id])
    end

    def get_tags
      @tags = Entry.tag_counts_on(:tags, order: 'name asc')
    end

    def entry_params
      params.require(:entry).permit(:title, :body, :slug, :status, :tag_list, photos_attributes: [:source_url, :source_file, :id, :_destroy, :position, :caption, :camera_list, :lense_list, :film_list])
    end

    def get_redirect_url(entry)
      if entry.is_published?
        admin_entries_path
      elsif entry.is_queued?
        queued_admin_entries_path
      else
        drafts_admin_entries_path
      end
    end
end
