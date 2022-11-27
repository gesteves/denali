class Activitypub::ProfileController < ActivitypubController
  def show
    @profile = Profile.find_by_username(params[:username])
    if @profile.present? && is_activitystream_request?
      render
    elsif @profile.present?
      redirect_to profile_url(username: @profile.username)
    else
      render json: {}, status: 401
    end
  end
end
