class Admin::TagCustomizationsController < AdminController
  def index
    # TODO: Find a better way to sort this.
    @tag_customizations = @photoblog.tag_customizations.all.sort { |a,b| a.tags.map { |t| t.slug.gsub('-', '') }.sort.join('') <=> b.tags.map { |t| t.slug.gsub('-', '') }.sort.join('') }
    @page_title = 'Tags & social media'
  end

  def new
    @tags = ActsAsTaggableOn::Tag.order('taggings_count desc')
    @tag_customization = @photoblog.tag_customizations.new
    @page_title = 'Set up a tag'
  end

  def create
    @tags = ActsAsTaggableOn::Tag.order('taggings_count desc')
    @tag_customization = TagCustomization.new(association_params)
    @tag_customization.blog = @photoblog
    respond_to do |format|
      if @tag_customization.save
        flash[:success] = "Tag settings saved!"
        format.html { redirect_to admin_tag_customizations_path }
      else
        flash[:warning] = 'The tag settings couldn’t be saved…'
        format.html { render :new }
      end
    end
  end

  def edit
    @tags = ActsAsTaggableOn::Tag.order('taggings_count desc')
    @tag_customization = @photoblog.tag_customizations.find(params[:id])
    @page_title = 'Edit tag settings'
  end

  def update
    @tags = ActsAsTaggableOn::Tag.order('taggings_count desc')
    @tag_customization = @photoblog.tag_customizations.find(params[:id])
    respond_to do |format|
      if @tag_customization.update(association_params)
        format.html {
          flash[:success] = 'Your changes were saved!'
          redirect_to admin_tag_customizations_path
        }
      else
        format.html {
          flash[:warning] = 'Your changes couldn’t be saved…'
          render :edit
        }
      end
    end
  end

  def destroy
    @tag_customization = @photoblog.tag_customizations.find(params[:id])
    @tag_customization.destroy
    respond_to do |format|
      format.html { redirect_to admin_tag_customizations_path }
    end
  end

  private

  def association_params
    params.require(:tag_customization).permit(:instagram_hashtags, :instagram_location_id, :instagram_location_name, :flickr_groups, :flickr_albums, :tag_list, :tumblr_tags)
  end
end
