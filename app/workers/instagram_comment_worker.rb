class InstagramCommentWorker < ApplicationWorker
  sidekiq_options queue: 'low'

  def perform(update_id)
    return if ENV['buffer_access_token'].blank?
    response = HTTParty.get("https://api.bufferapp.com/1/updates/#{update_id}.json?access_token=#{ENV['buffer_access_token']}")
    update = JSON.parse(response.body)
    if update['status'] == 'sent' && update['comment_enabled'] && !update.dig('comment_state', 'success')
      logger.error "[Instagram] [#{update_id}] #{update.dig('comment_state', 'error')}"
    end
  end
end
