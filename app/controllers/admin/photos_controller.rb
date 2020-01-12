class Admin::PhotosController < AdminController

  def download
    entry = Entry.find(params[:entry_id])
    photo = entry.photos.find(params[:id])
    redirect_to photo.image.service_url(disposition: :attachment)
  end

end
