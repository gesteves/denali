class Admin::PhotosController < AdminController
  before_action :set_photo, only: [:generate_alt_text, :approve_alt_text]

  def download
    entry = Entry.find(params[:entry_id])
    photo = entry.photos.find(params[:id])
    redirect_to photo.image.url(disposition: :attachment)
  end

  def focal_point
    @entry = Entry.find(params[:entry_id])
    @photo = @entry.photos.find(params[:id])
    @photo.update(photo_params)
    message = 'The focal point has been updated.'
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

  def generate_alt_text
    AltTextWorker.perform_inline(params[:id])
    @photo.reload
    respond_to do |format|
      format.json {
        render json: {
          status: 'success',
          auto_generated_alt_text: @photo.auto_generated_alt_text
        }
      }
    end
  end

  def approve_alt_text
    @photo.approve_auto_generated_alt_text!(params[:text])
    respond_to do |format|
      format.json {
        render json: {
          status: 'success',
          alt_text: @photo.alt_text
        }
      }
    end
  end

  private

  def set_photo
    @photo = Photo.find(params[:id])
  end

  def photo_params
    params.require(:photo).permit(:focal_x, :focal_y)
  end
end
