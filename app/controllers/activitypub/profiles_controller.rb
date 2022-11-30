class Activitypub::ProfilesController < ActivitypubController
  def show
    @user = User.find(params[:user_id])
    if is_activitypub_request?
      render
    else
      redirect_to root_url
    end
  end
end
