class Admin::BlogsController < AdminController
  # GET /admin/blogs/1/edit
  def edit
    @page_title = 'Blog settings'
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
        @photoblog.settings_changed!
        CachePurgeJob.enqueue(*@photoblog.cache_tags)
        # The publication record carries the blog's name, description, icon and discovery
        # preference, so saving settings is exactly when it needs rewriting. It lives here rather
        # than in a model callback because `belongs_to :blog, touch: true` updates a blog row every
        # time an entry is saved, and a callback there can't tell that apart from a real edit.
        StandardSiteJob.perform_async('sync_publication') if @photoblog.standard_site_enabled?
        format.html {
          flash[:success] = 'Your changes were saved!'
          redirect_to edit_admin_blog_path(@photoblog)
        }
      else
        format.html {
          flash[:warning] = 'Your changes couldn’t be saved…'
          render :edit, status: :unprocessable_entity
        }
      end
    end
  end

  private

  def blog_params
    params.require(:blog).permit(:name, :posts_per_page, :about,
                                 :show_related_entries, :analytics_head, :analytics_body,
                                 :email, :flickr, :mastodon, :bluesky, :instagram, :threads,
                                 :header_logo_svg, :additional_meta_tags,
                                 :favicon, :touch_icon, :logo, :og_image, :placeholder, :time_zone, :meta_description,
                                 :show_search, :hide_from_search_engines, :standard_site_social_account_id)
  end
end
