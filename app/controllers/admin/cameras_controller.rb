class Admin::CamerasController < AdminController
  def edit
    @camera = Camera.find(params[:id])
    @page_title = 'Editing camera'
  end

  def update
    @camera = Camera.find(params[:id])
    respond_to do |format|
      if @camera.update(camera_params)
        format.html {
          flash[:success] = 'Your changes were saved!'
          redirect_to admin_equipment_path
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
  def camera_params
    params.require(:camera).permit(:make, :model, :display_name, :is_phone)
  end
end
