class SlackJob < ApplicationJob
  queue_as :default

  def perform(text = '', attachment = nil, channel = nil)
    payload = { text: text }
    payload[:attachments] = [attachment] if attachment.present?
    payload[:channel] = channel if channel.present?
    if Rails.env.production? && ENV['slack_incoming_webhook'].present?
      response = HTTParty.post(ENV['slack_incoming_webhook'], body: payload.to_json)
      if response.code >= 400
        raise response.body
      end
    end
  end
end
