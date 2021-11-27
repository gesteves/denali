class Admin::CropsController < AdminController

  def create_or_update
    @entry = Entry.find(params[:entry_id])
    @photo = @entry.photos.find(params[:photo_id])
    crop = @photo.crops.find_or_create_by(name: crop_params[:name])
    crop.update(crop_params)
    logger.info crop.inspect
    message = 'The crop has been updated.'
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
  def crop_params
    params.require(:crop).permit(:x, :y, :width, :height, :name)
  end
end
