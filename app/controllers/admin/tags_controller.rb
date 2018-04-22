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
        format.json
      else
        format.json render plain: 'Could not update tag', status: 400
      end
    end
  end

  def add
    new_tags = params[:tags]
    tag = ActsAsTaggableOn::Tag.find(params[:id])
    entries = @photoblog.entries.tagged_with(tag.name)
    entries.map { |e| e.add_tags(new_tags) }
    respond_to do |format|
      format.html { redirect_to admin_tags_path }
      format.json {
        response = {
          status: 200,
          message: "#{entries.size} entries with the tag #{tag.name} updated with the tag #{new_tags}"
        }
        render json: response
      }
    end
  end
end
