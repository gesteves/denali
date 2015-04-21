class Admin::BlogsController < AdminController

  # GET /admin/blogs/1/edit
  def edit
  end

  # PATCH/PUT /admin/blogs/1
  # PATCH/PUT /admin/blogs/1.json
  def update
    respond_to do |format|
      if @blog.update(params[:blog])
        format.html { redirect_to admin_settings_path, notice: 'Blog was successfully updated.' }
      else
        format.html { render :edit }
      end
    end
  end
end
