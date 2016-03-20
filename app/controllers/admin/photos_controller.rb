class Admin::PhotosController < AdminController
  def index
    @page = params[:page] || 1
    @photos = Photo.where('caption = ?', '').order('created_at DESC').page(@page).includes(:entry)
    @page_title = 'Photos without caption'
  end

  def update
    @photo = Photo.find(params[:id])
    respond_to do |format|
      if @photo.update(entry_params)
        logger.info "Photo #{@photo.id} was updated."
        flash[:notice] = 'Your photo was updated!'
        format.html { redirect_to admin_photos_path }
      else
        flash[:alert] = 'Your photo couldn’t be updated…'
      end
      format.html { redirect_to admin_photos_path }
    end
  end

  private

  def entry_params
    params.require(:photo).permit(:caption)
  end
end
