class PushSubscriptionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create]

  def create
    subscription = push_subscription_params
    push_subscription = PushSubscription.find_or_create_by(endpoint: subscription[:endpoint]) do |ps|
      ps.blog = @photoblog
      ps.p256dh = subscription[:keys][:p256dh]
      ps.auth = subscription[:keys][:auth]
    end

    if push_subscription.save
      render json: { status: 'success' }, status: :created
    else
      render json: { errors: push_subscription.errors }, status: :unprocessable_entity
    end
  end

  private

  def push_subscription_params
    params.permit(:endpoint, :expirationTime, keys: [:p256dh, :auth], push_subscription: [:endpoint])
  end
end
