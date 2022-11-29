class Activitypub::ActivitiesController < ApplicationController
  def show
    @user = User.find(params[:user_id])
    @entry = @photoblog.entries.includes(photos: [:image_attachment, :image_blob]).published.by_user(@user).find(params[:activity_id])
    raise ActiveRecord::RecordNotFound if @entry.blank?
  end
end
