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
        format.html {
          flash[:success] = 'Your changes were saved!'
          redirect_to admin_settings_path
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

  def blog_params
    params.require(:blog).permit(:name, :description, :posts_per_page, :domain,
                                 :short_domain, :about, :copyright,
                                 :show_related_entries, :analytics_code,
                                 :instagram, :twitter, :tumblr, :email, :flickr,
                                 :header_logo_svg, :additional_meta_tags,
                                 :favicon, :touch_icon, :logo, :facebook)
  end
end
