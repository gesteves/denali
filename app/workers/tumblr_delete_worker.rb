class TumblrDeleteWorker < ApplicationWorker
  sidekiq_options queue: 'low'

  def perform(tumblr_username, tumblr_id)
    return if !Rails.env.production?
    return if ENV['TUMBLR_CONSUMER_KEY'].blank? || ENV['TUMBLR_CONSUMER_SECRET'].blank? || ENV['TUMBLR_ACCESS_TOKEN'].blank? || ENV['TUMBLR_ACCESS_TOKEN_SECRET'].blank?

    response = tumblr.delete(tumblr_username, tumblr_id)
    raise response.to_s if response['errors'].present? || (response['status'].present? && response['status'] >= 400)
  end
end
