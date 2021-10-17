class Admin::ParksController < AdminController
  def edit
    @park = Park.find(params[:id])
    @page_title = 'Editing national park'
  end

  def update
    @park = Park.find(params[:id])
    respond_to do |format|
      if @park.update(park_params)
        format.html {
          flash[:success] = 'Your changes were saved!'
          redirect_to admin_locations_path
        }
      else
        format.html {
          flash[:warning] = 'Your changes couldn’t be saved…'
          render :edit
        }
      end
    end
  end

  private
  def park_params
    params.require(:park).permit(:display_name, :url, :full_name, :short_name, :designation)
  end
end
