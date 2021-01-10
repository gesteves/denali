class Admin::PhotosController < AdminController

  def download
    entry = Entry.find(params[:entry_id])
    photo = entry.photos.find(params[:id])
    redirect_to photo.image.url(disposition: :attachment)
  end

  def crops
    @entry = Entry.find(params[:entry_id])
    @photo = @entry.photos.find(params[:id])

    @photo.update(photo_params)
    respond_to do |format|
      format.js
    end
  end

  private
  def photo_params
    params.require(:photo).permit(:focal_x, :focal_y)
  end
end
