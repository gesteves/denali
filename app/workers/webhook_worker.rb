class WebhookWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  def perform(webhook_id, entry_id)
    return if !Rails.env.production?

    webhook = Webhook.find(webhook_id)
    entry = Entry.published.find(entry_id)
    payload = webhook.payload(entry)

    response = if payload.present?
      HTTParty.post(webhook.url, body: payload, headers: { 'Content-Type': 'application/json' })
    else
      HTTParty.post(webhook.url)
    end

    if response.code >= 400
      raise "Failed to send webhook: #{response.body}"
    end
  end
end
