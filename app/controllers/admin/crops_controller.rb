class Admin::CropsController < AdminController

  def create_or_update
    @entry = Entry.find(params[:entry_id])
    @photo = @entry.photos.find(params[:photo_id])
    crop = @photo.crops.find_or_create_by(aspect_ratio: crop_params[:aspect_ratio])
    if crop.update(crop_params)
      message = "The crop has been updated."
      status = 'success'
      code = 200
    else
      message = "The crop couldn't be updated."
      status = 'danger'
      code = 500
    end
    respond_to do |format|
      format.json {
        response = {
          status: status,
          message: message
        }
        render json: response, code: code
      }
    end
  end

  private
  def crop_params
    params.require(:crop).permit(:x, :y, :width, :height, :aspect_ratio)
  end
end
