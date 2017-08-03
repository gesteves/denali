class Admin::TagsController < AdminController
  def index
    @page = params[:page] || 1
    @tags = ActsAsTaggableOn::Tag.order('name asc').page(@page).per(100)
    @page_title = 'Tags'
  end

  def destroy
    @tag = ActsAsTaggableOn::Tag.find(params[:id]).destroy
    respond_to do |format|
      format.html { redirect_to admin_tags_path }
      format.json {
        response = {
          status: 200,
          message: 'Tag deleted'
        }
        render json: response
      }
    end
  end

  def show
    tag = ActsAsTaggableOn::Tag.find(params[:id])
    redirect_to admin_tagged_entries_path(tag.slug)
  end

  def update
    @tag = ActsAsTaggableOn::Tag.find(params[:id])
    respond_to do |format|
      if @tag.update(name: params[:name])
        format.js
      else
        format.js render plain: 'Could not update tag', status: 400
      end
    end
  end
end
