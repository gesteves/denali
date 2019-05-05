class Admin::FilmsController < AdminController
  def edit
    @film = Film.find(params[:id])
    @page_title = 'Editing film'
  end

  def update
    @film = Film.find(params[:id])
    respond_to do |format|
      if @film.update(film_params)
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
  def film_params
    params.require(:film).permit(:make, :model, :display_name)
  end
end
