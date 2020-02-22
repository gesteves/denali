class Admin::BlogsController < AdminController
  # GET /admin/blogs/1/edit
  def edit
    @page_title = 'Blog settings'
    @map_styles = [
      ['Streets', 'mapbox://styles/mapbox/streets-v11'],
      ['Outdoors', 'mapbox://styles/mapbox/outdoors-v11'],
      ['Light', 'mapbox://styles/mapbox/light-v10'],
      ['Dark', 'mapbox://styles/mapbox/dark-v10'],
      ['Satellite', 'mapbox://styles/mapbox/satellite-v9'],
      ['Satellite streets', 'mapbox://styles/mapbox/satellite-streets-v11'],
    ]
  end

  # PATCH/PUT /admin/blogs/1
  # PATCH/PUT /admin/blogs/1.json
  def update
    respond_to do |format|
      if @photoblog.update(blog_params)
        format.html {
          flash[:success] = 'Your changes were saved!'
          redirect_to edit_admin_blog_path(@photoblog)
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
    params.require(:blog).permit(:name, :tag_line, :posts_per_page, :about, :copyright,
                                 :show_related_entries, :analytics,
                                 :instagram, :twitter, :tumblr, :email, :flickr,
                                 :header_logo_svg, :additional_meta_tags,
                                 :favicon, :touch_icon, :logo, :facebook, :time_zone, :meta_description, :map_style)
  end
end
