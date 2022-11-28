class Activitypub::OutboxController < ActivitypubController
  before_action :find_profile, :set_pages

  def index

  end

  def entries
    @page = params[:page].to_i
    @entries = @photoblog.entries.includes(photos: [:image_attachment, :image_blob]).published.by_user(@profile.user).photo_entries.page(@page).per(@count)
    raise ActiveRecord::RecordNotFound if @entries.empty?
  end

  private

  def find_profile
    @profile = Profile.find_by_username(params[:username])
    raise ActiveRecord::RecordNotFound if @profile.blank?
  end

  def set_pages
    @count = @photoblog.posts_per_page
    @total_entries = @photoblog.entries.published.by_user(@profile.user).photo_entries.count
    pages = (@total_entries.to_f/@count).ceil
    @first_page = @total_entries > 1 ? activitypub_outbox_list_url(username: @profile.username, page: 1) : nil
    @last_page = @total_entries > 1 ? activitypub_outbox_list_url(username: @profile.username, page: pages) : nil
  end
end
