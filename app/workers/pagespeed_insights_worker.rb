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

    preamble = "[Pagespeed Insights] [#{strategy.titlecase}]"

    fcp = metrics&.dig(:firstContentfulPaint)&.to_i
    tti = metrics&.dig(:interactive)&.to_i
    si = metrics&.dig(:speedIndex)&.to_i
    tbt = metrics&.dig(:totalBlockingTime)&.to_i
    lcp = metrics&.dig(:largestContentfulPaint)&.to_i
    cls = metrics&.dig(:cumulativeLayoutShift)&.to_f&.round(3)
    score = (performance_score * 100).to_i

    logger.info "#{preamble} Results for #{url}"

    if fcp.present?
      msg = "#{preamble} First Contentful Paint: #{fcp} ms"
      if fcp <= 2000
        logger.info { msg }
      elsif fcp <= 4000
        logger.warn { msg }
      else
        logger.error { msg }
      end
    end

    if lcp.present?
      msg = "#{preamble} Largest Contentful Paint: #{lcp} ms"
      if lcp <= 2000
        logger.info { msg }
      elsif lcp <= 4000
        logger.warn { msg }
      else
        logger.error { msg }
      end
    end

    if cls.present?
      msg = "#{preamble} Cumulative Layout Shift: #{cls}"
      if cls <= 0.1
        logger.info { msg }
      elsif cls <= 0.25
        logger.warn { msg }
      else
        logger.error { msg }
      end
    end

    if tti.present?
      msg = "#{preamble} Time to Interactive: #{tti} ms"
      if tti <= 3800
        logger.info { msg }
      elsif tti <= 7300
        logger.warn { msg }
      else
        logger.error { msg }
      end
    end

    if tbt.present?
      msg = "#{preamble} Total Blocking Time: #{tbt} ms"
      if tbt <= 300
        logger.info { msg }
      elsif tbt <= 600
        logger.warn { msg }
      else
        logger.error { msg }
      end
    end

    if si.present?
      msg = "#{preamble} Speed Index: #{si}"
      if si <= 4300
        logger.info { msg }
      elsif si <= 5800
        logger.warn { msg }
      else
        logger.error { msg }
      end
    end

    if score.present?
      msg = "#{preamble} Performance Score: #{score}"
      if score >= 90
        logger.info { msg }
      elsif score >= 80
        logger.warn { msg }
      else
        logger.error { msg }
      end
    end
  end
end
