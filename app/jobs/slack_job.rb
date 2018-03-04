class SlackJob < ApplicationJob
  queue_as :default

  def perform(opts = {})
    return if !Rails.env.production? || ENV['slack_incoming_webhook'].blank?
    opts.reverse_merge!(text: '')
    response = HTTParty.post(ENV['slack_incoming_webhook'], body: opts.to_json)
    if response.code >= 400
      raise response.body
    end
  end
end
