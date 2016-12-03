class Admin::TagsController < AdminController
  def index
    @tags = ActsAsTaggableOn::Tag.all.order('name asc')
  end

  def destroy
    @tag = ActsAsTaggableOn::Tag.find(params[:id]).destroy
    redirect_to admin_tags_path
  end
end
