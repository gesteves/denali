class Admin::TagAssociationsController < AdminController
  def index
    @page = params[:page] || 1
    @tag_associations = @photoblog.tag_associations.page(@page)
    @page_title = 'Tags & social media'
  end

  def new
    @tags = ActsAsTaggableOn::Tag.order('taggings_count desc')
    @tag_association = @photoblog.tag_associations.new
    @page_title = 'Set up a tag'
  end

  def create
    @tag_association = TagAssociation.new(association_params)
    @tag_association.blog = @photoblog
    respond_to do |format|
      if @tag_association.save
        flash[:success] = "Tag settings saved!"
        format.html { redirect_to admin_tag_associations_path }
      else
        flash[:warning] = 'The tag settings couldn’t be saved…'
        format.html { render :new }
      end
    end
  end

  def edit
    @tags = ActsAsTaggableOn::Tag.order('taggings_count desc')
    @tag_association = @photoblog.tag_associations.find(params[:id])
    @page_title = 'Edit tag settings'
  end

  def update
    @tag_association = @photoblog.tag_associations.find(params[:id])
    respond_to do |format|
      if @tag_association.update(association_params)
        format.html {
          flash[:success] = 'Your changes were saved!'
          redirect_to admin_tag_associations_path
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
    @tag_association = @photoblog.tag_associations.find(params[:id])
    @tag_association.destroy
    respond_to do |format|
      format.html { redirect_to admin_tag_associations_path }
    end
  end

  private

  def association_params
    params.require(:tag_association).permit(:instagram_hashtags, :flickr_groups, :tag_list)
  end
end
