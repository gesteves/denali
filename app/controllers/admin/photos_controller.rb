class Admin::PhotosController < AdminController

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

  def banner
    @entry = Entry.find(params[:entry_id])
    @photo = @entry.photos.find(params[:id])
    @profile.photo = @photo
    if @profile.save
      @message = 'The banner image has been updated.'
      respond_to do |format|
        format.html {
          flash[:success] = @message
          redirect_to session[:redirect_url] || admin_entry_path(@entry)
        }
        format.js { render 'admin/shared/notify' }
      end
    end
  end

  private
  def photo_params
    params.require(:photo).permit(:focal_x, :focal_y)
  end
end
