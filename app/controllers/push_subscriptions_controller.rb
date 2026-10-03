class PushSubscriptionsController < ApplicationController
  skip_before_action :verify_authenticity_token
  rate_limit to: 10, within: 1.minute, by: -> { client_ip }

  def create
    subscription = push_subscription_params
    # A browser that resubscribes keeps its endpoint but may rotate its keys.
    push_subscription = PushSubscription.find_or_initialize_by(endpoint: subscription[:endpoint])
    push_subscription.assign_attributes(
      blog: @photoblog,
      p256dh: subscription.dig(:keys, :p256dh),
      auth: subscription.dig(:keys, :auth)
    )

    if push_subscription.save
      render json: { status: 'success' }, status: :created
    else
      render json: { errors: push_subscription.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    subscription = push_subscription_params
    push_subscription = PushSubscription.find_by(endpoint: subscription[:endpoint])

    if push_subscription
      push_subscription.destroy
      render json: { status: 'ok' }, status: :ok
    else
      render json: { status: 'not found' }, status: :not_found
    end
  end

  private

  def push_subscription_params
    params.permit(:endpoint, :expirationTime, keys: [:p256dh, :auth], push_subscription: [:endpoint])
  end
end
