class Admin::CropsController < AdminController

  def create_or_update
    @entry = Entry.find(params[:entry_id])
    @photo = @entry.photos.find(params[:photo_id])
    Rails.logger.info "Crop params for photo #{@photo.id}: #{crop_params.to_h.inspect}"
    crop = find_or_create_crop(crop_params[:aspect_ratio])
    if crop.update(crop_params)
      message = "The crop has been updated."
      status = 'success'
      code = :ok
    else
      Rails.logger.error "Crop update failed for photo #{@photo.id}: #{crop.errors.full_messages.join(', ')}"
      message = "The crop couldn’t be updated."
      status = 'danger'
      code = :unprocessable_content
    end
    respond_to do |format|
      format.json {
        response = {
          status: status,
          message: message
        }
        render json: response, status: code
      }
    end
  end

  private

  # The crop editor can send two saves for the same aspect ratio at once, and
  # both can miss the crop. That's where the duplicate crops came from; now the
  # unique index lets one request create it, and the other updates that row.
  def find_or_create_crop(aspect_ratio)
    crop = @photo.crops.find_or_create_by(aspect_ratio: aspect_ratio)
    # The uniqueness validation can lose the race too, if the other request
    # committed between this one's lookup and its insert.
    crop.errors.of_kind?(:aspect_ratio, :taken) ? @photo.crops.find_by!(aspect_ratio: aspect_ratio) : crop
  rescue ActiveRecord::RecordNotUnique
    @photo.crops.find_by!(aspect_ratio: aspect_ratio)
  end

  def crop_params
    params.require(:crop).permit(:x, :y, :width, :height, :aspect_ratio)
  end
end
