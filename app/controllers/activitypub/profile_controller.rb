class Activitypub::ProfileController < ActivitypubController
  def show
    @profile = Profile.find_by_username(params[:username])
    raise ActiveRecord::RecordNotFound if @profile.blank?
    if is_activitypub_request?
      render
    else
      redirect_to profile_url(username: @profile.username)
    end
  end
end
