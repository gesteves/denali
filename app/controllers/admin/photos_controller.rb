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
    message = if photo_params[:focal_x].present? || photo_params[:focal_y].present?
      'The focal point has been updated.'
    elsif photo_params[:facebook_crop].present? || photo_params[:twitter_crop].present? || photo_params[:square_crop].present?
      'The crop has been updated.'
    end
    respond_to do |format|
      format.json {
        response = {
          status: 'success',
          message: message
        }
        render json: response
      }
    end
  end

  private
  def photo_params
    params.require(:photo).permit(:focal_x, :focal_y, :square_crop, :twitter_crop, :facebook_crop)
  end
end
