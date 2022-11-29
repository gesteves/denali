class Activitypub::ActivitiesController < ApplicationController
  def show
    @profile = Profile.find_by_username(params[:username])
    raise ActiveRecord::RecordNotFound if @profile.blank?
    @entry = @photoblog.entries.includes(photos: [:image_attachment, :image_blob]).published.by_user(@profile.user).find(params[:id])
    raise ActiveRecord::RecordNotFound if @entry.empty?
  end
end
