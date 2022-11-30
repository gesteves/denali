class Activitypub::ProfilesController < ActivitypubController
  def show
    @user = User.find(params[:user_id])
    if is_activitypub_request?
      render
    else
      redirect_to profile_url(username: @user.profile.username)
    end
  end
end
