class PagespeedInsightsWorker < ApplicationWorker
  sidekiq_options queue: 'low'

  def perform(entry_id, strategy = 'desktop')
    return if !Rails.env.production?
    return if ENV['google_api_key'].blank?
    return unless ['desktop', 'mobile'].include? strategy
    entry = Entry.find(entry_id)
    raise UnprocessedPhotoError if entry.is_photo? && !entry.photos_processed?

    url = entry.permalink_url

    params = {
      url: url,
      strategy: strategy.upcase,
      key: ENV['google_api_key']
    }

    response = HTTParty.get('https://pagespeedonline.googleapis.com/pagespeedonline/v5/runPagespeed', query: params)
    response = JSON.parse(response.body).with_indifferent_access

    metrics = response.dig(:lighthouseResult, :audits, :metrics, :details, :items)&.first
    performance_score = response.dig(:lighthouseResult, :categories, :performance, :score)

    logger.info "[Pagespeed Insights] #{strategy.titlecase} results for #{url}"
    logger.info "[Pagespeed Insights] First Contentful Paint: #{metrics&.dig(:firstContentfulPaint)&.to_i} ms"
    logger.info "[Pagespeed Insights] Largest Contentful Paint: #{metrics&.dig(:largestContentfulPaint)&.to_i} ms"
    logger.info "[Pagespeed Insights] Cumulative Layout Shift: #{metrics&.dig(:cumulativeLayoutShift)&.to_f&.round(3)}"
    logger.info "[Pagespeed Insights] Total Blocking Time: #{metrics&.dig(:totalBlockingTime)&.to_i} ms"
    logger.info "[Pagespeed Insights] Speed Index: #{metrics&.dig(:speedIndex)}"
    logger.info "[Pagespeed Insights] Score: #{performance_score}"
  end
end
