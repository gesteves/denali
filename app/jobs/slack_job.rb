class SlackJob < ApplicationJob
  queue_as :default

  def perform(text = '', attachment = nil, channel = nil)
    payload = { text: text }
    payload[:attachments] = [attachment] if attachment.present?
    payload[:channel] = channel if channel.present?
    response = HTTParty.post(ENV['slack_incoming_webhook'], body: payload.to_json) if !Rails.env.test? && ENV['slack_incoming_webhook'].present?
    if response.code >= 400
      raise response.body
    end
  end
end
