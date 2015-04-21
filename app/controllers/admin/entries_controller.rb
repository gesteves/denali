class Admin::EntriesController < ApplicationController
  before_action :set_entry, only: [:show, :edit, :update, :destroy]

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

  # POST /admin/entries
  def create
    @entry = Entry.new(entry_params)

    respond_to do |format|
      if @entry.save
        format.html { redirect_to admin_entries_path, notice: 'Entry was successfully created.' }
      else
        format.html { render :new }
      end
    end
  end

  # PATCH/PUT /admin/entries/1
  def update
    respond_to do |format|
      if @entry.update(entry_params)
        format.html { redirect_to admin_entries_path, notice: 'Entry was successfully updated.' }
      else
        format.html { render :edit }
      end
    end
  end

  # DELETE /admin/entries/1
  def destroy
    @entry.destroy
    respond_to do |format|
      format.html { redirect_to admin_entries_path, notice: 'Entry was successfully destroyed.' }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_entry
      @entry = Entry.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def entry_params
      params.require(:entry).permit(:title, :body)
    end
end
