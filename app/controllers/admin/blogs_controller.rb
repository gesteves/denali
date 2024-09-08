class Admin::BlogsController < AdminController
  skip_before_action :verify_authenticity_token, only: [:flush_caches]

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
    @ttls = [
      ['Don’t cache', 0],
      ['1 minute',    1.minute],
      ['5 minutes',   5.minutes],
      ['15 minutes',  15.minutes],
      ['1 hour',      1.hour],
      ['1 day',       1.day],
      ['1 week',      1.week],
      ['1 month',     1.month],
      ['1 year',      1.year]
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

  def flush_caches
    @photoblog.purge_from_cdn
    @message = 'Caches are being cleared. This may take a few moments.'
    respond_to do |format|
      format.html {
        flash[:success] = @message
        redirect_to session[:redirect_url] || admin_entry_path(@entry)
      }
      format.js { render 'admin/shared/notify' }
    end
  end

  private

  def blog_params
    params.require(:blog).permit(:name, :tag_line, :posts_per_page, :about, :copyright,
                                 :show_related_entries, :analytics_head, :analytics_body,
                                 :instagram, :email, :flickr, :mastodon, :bluesky,
                                 :header_logo_svg, :additional_meta_tags,
                                 :favicon, :touch_icon, :logo, :placeholder, :time_zone, :meta_description, :map_style,
                                 :show_search)
  end
end
