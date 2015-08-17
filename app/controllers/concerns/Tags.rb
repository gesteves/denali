module Tags
  extend ActiveSupport::Concern

  def load_tags
    @tag_slug = params[:tag]
    @tags = ActsAsTaggableOn::Tag.where(slug: params[:tag])
    @tag_list = @tags.map{ |t| t.name }
  end
end
