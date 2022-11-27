class Activitypub::OutboxController < ActivitypubController
  def index
    @profile = Profile.find_by_username(params[:username])
    raise ActiveRecord::RecordNotFound if @profile.blank?
    @count = @photoblog.posts_per_page
    @total_entries = @photoblog.entries.published.where(user: @profile.user).photo_entries.count
    pages = (@total_entries.to_f/@count).ceil
    @first_page = @total_entries > 1 ? activitypub_outbox_list_url(username: @profile.username, page: 1) : nil
    @last_page = @total_entries > 1 ? activitypub_outbox_list_url(username: @profile.username, page: pages) : nil
  end
end
