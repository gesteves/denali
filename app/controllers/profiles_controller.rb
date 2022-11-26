class ProfilesController < ApplicationController
  def show
    @profile = Profile.find_by_username(params[:username])
    redirect_to root_path if @profile.present? && request.headers['Accept'].match?('application/ld+json')
  end
end
