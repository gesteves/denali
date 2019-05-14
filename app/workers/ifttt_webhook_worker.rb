class IftttWebhookWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  def perform(event, payload)
    return if !Rails.env.production? || ENV['ifttt_webhook_key'].blank? || event.blank? || payload.blank?
    url = "https://maker.ifttt.com/trigger/#{event}/with/key/#{ENV['ifttt_webhook_key']}"
    response = HTTParty.post(url, body: payload.to_json, headers: { 'Content-Type': 'application/json' })
    if response.code >= 400
      raise "Failed to send webhook to IFTTT: #{response.body}"
    else
      logger.info "[IFTTT] Webhook sent for #{event} event"
    end
  end
end
