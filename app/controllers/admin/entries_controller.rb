class Admin::EntriesController < ApplicationController
  before_action :set_entry, only: [:show, :edit, :update, :destroy, :publish]

  # GET /admin/entries
  def index
    @entries = Entry.published
  end

  # GET /admin/entries/queued
  def queued
    @entries = Entry.queued
  end

  # GET /admin/entries/drafts
  def drafts
    @entries = Entry.drafted
  end

  # GET /admin/entries/new
  def new
    @entry = Entry.new
  end

  # GET /admin/entries/1/edit
  def edit
  end

  # PATCH /admin/entries/1/publish
  def publish
    @entry.published = true
    @entry.draft = false
    @entry.queued = false
    @entry.published_at = Time.now
    if @entry.save
      respond_to do |format|
        format.html { redirect_to admin_entries_path, notice: 'Entry was successfully published.' }
      end
    else
      respond_to do |format|
        format.html { redirect_to request.referrer, notice: 'Entry couldn\'t be published.' }
      end
    end
  end

  # POST /admin/entries
  def create
    @entry = Entry.new(params[:entry])
    @entry.user = current_user
    @entry.blog = photoblog
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
      if @entry.update(params[:entry])
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

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_entry
      @entry = Entry.find(params[:id])
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
