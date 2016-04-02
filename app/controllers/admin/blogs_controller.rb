class Admin::BlogsController < AdminController
  # GET /admin/blogs/1/edit
  def edit
    @blog = @photoblog
    @page_title = 'Blog settings'
  end

  # PATCH/PUT /admin/blogs/1
  # PATCH/PUT /admin/blogs/1.json
  def update
    respond_to do |format|
      if @photoblog.update(blog_params)
        format.html { redirect_to admin_settings_path, notice: 'Blog was successfully updated.' }
      else
        format.html { render :edit }
      end
    end
  end

  private

  def blog_params
    params.require(:blog).permit(:name, :description, :posts_per_page, :domain, :short_domain, :about, :copyright)
  end
end
