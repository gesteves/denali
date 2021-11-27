class Admin::CropsController < AdminController

  def create_or_update
    @entry = Entry.find(params[:entry_id])
    @photo = @entry.photos.find(params[:photo_id])
    crop = @photo.crops.find_or_create_by(name: crop_params[:name])
    if crop.update(crop_params)
      message = "The #{crop_params[:name].titleize} crop has been updated."
      status = 'success'
    else
      message = "The #{crop_params[:name].titleize} crop couldn't be updated."
      status = 'danger'
    end
    respond_to do |format|
      format.json {
        response = {
          status: status,
          message: message
        }
        render json: response
      }
    end
  end

  private
  def crop_params
    params.require(:crop).permit(:x, :y, :width, :height, :name)
  end
end
