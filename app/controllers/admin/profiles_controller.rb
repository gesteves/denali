class Admin::ProfilesController < AdminController

  # GET /admin/blogs/1/edit
  def edit
    @profile = @current_user.profile
    @page_title = "Editing “#{@profile.name}”"
  end

  # PATCH/PUT /admin/blogs/1
  # PATCH/PUT /admin/blogs/1.json
  def update
    @profile = @current_user.profile
    respond_to do |format|
      if @profile.update(profile_params)
        format.html {
          flash[:success] = 'Your changes were saved!'
          redirect_to edit_admin_profile_path(@profile)
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

  def profile_params
    params.require(:profile).permit(:username, :name, :instagram, :website, :tumblr, :flickr, :email, :summary, :bio, :meta_description, :avatar)
  end
end
