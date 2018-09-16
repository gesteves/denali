class IftttWebhookJob < ApplicationJob
  queue_as :default

  def perform(event_name, payload)
    return if !Rails.env.production? || ENV['ifttt_webhook_key'].blank?
    url = "https://maker.ifttt.com/trigger/#{event_name}/with/key/#{ENV['ifttt_webhook_key']}"
    response = HTTParty.post(url, body: payload, headers: { 'Content-Type': 'application/json' })
    if response.code >= 400
      logger.tagged('IFTTT') { logger.error response.body }
    end
  end
end
