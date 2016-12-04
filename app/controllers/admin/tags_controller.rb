class Admin::TagsController < AdminController
  def index
    @page = params[:page] || 1
    @tags = ActsAsTaggableOn::Tag.order('name asc').page(@page).per(20)
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
end
