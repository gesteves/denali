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
    @ttls = [
      ['Don’t cache', 0],
      ['5 minutes',   5.minutes],
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
        HerokuConfigWorker.perform_async({ CACHE_TTL: blog_params[:cache_ttl] }.compact)
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
    Rails.cache.clear
    CloudfrontInvalidationWorker.perform_async('/*')
    HerokuConfigWorker.perform_async({ CACHE_VERSION: Time.now.to_i.to_s })
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
                                 :instagram, :twitter, :tumblr, :email, :flickr,
                                 :header_logo_svg, :additional_meta_tags,
                                 :favicon, :touch_icon, :logo, :facebook, :time_zone, :meta_description, :map_style,
                                 :cache_ttl)
  end
end
