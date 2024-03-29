class Activitypub::OutboxesController < ActivitypubController
  before_action :find_user, :set_pages

  def index

  end

  def activities
    @page = params[:page].to_i
    @entries = @photoblog.entries.includes(photos: [:image_attachment, :image_blob]).published.by_user(@user).photo_entries.page(@page).per(@count)
    raise ActiveRecord::RecordNotFound if @entries.empty?
    @current_page = activitypub_outbox_activities_url(user_id: @user.id, page: @page)
  end

  private

  def find_user
    @user = User.find(params[:user_id])
  end

  def set_pages
    @count = 100
    @total_entries = @photoblog.entries.published.by_user(@user).photo_entries.count
    @total_pages = (@total_entries.to_f/@count).ceil
    raise ActiveRecord::RecordNotFound if @total_entries == 0
  end
end
