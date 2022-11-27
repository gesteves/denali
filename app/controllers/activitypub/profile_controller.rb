class Activitypub::ProfileController < ActivitypubController
  def show
    @profile = Profile.find_by_username(params[:username])
    if is_activitystream_request? && @profile.present?
      render
    else
      render json: {}, status: 401
    end
  end
end
