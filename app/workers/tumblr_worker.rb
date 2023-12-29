class TumblrWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  def perform(entry_id, state = 'auto')
    return if !Rails.env.production?
    return if ENV['TUMBLR_CONSUMER_KEY'].blank? || ENV['TUMBLR_CONSUMER_SECRET'].blank? || ENV['TUMBLR_ACCESS_TOKEN'].blank? || ENV['TUMBLR_ACCESS_TOKEN_SECRET'].blank?

    entry = Entry.published.find(entry_id)
    return if !entry.is_photo?
    raise UnprocessedPhotoError if entry.is_photo? && !entry.photos_have_dimensions?

    tumblr_username = entry.user.profile.tumblr_username
    return if tumblr_username.blank?

    tumblr = Tumblr::Client.new({
      consumer_key: ENV['TUMBLR_CONSUMER_KEY'],
      consumer_secret: ENV['TUMBLR_CONSUMER_SECRET'],
      oauth_token: ENV['TUMBLR_ACCESS_TOKEN'],
      oauth_token_secret: ENV['TUMBLR_ACCESS_TOKEN_SECRET']
    })

    if state == 'auto'
      blog_info = tumblr.blog_info(tumblr_username)
      raise blog_info.to_s if blog_info['errors'].present? || (blog_info['status'].present? && blog_info['status'] >= 400)
      # If the queue is empty, publish directly; if not, send it to the back of the queue.
      state = blog_info['blog']['queue'] > 0 ? 'queue' : 'published'
    end

    opts = {
      tags: entry.tumblr_tags,
      slug: entry.slug,
      caption: entry.tumblr_caption,
      source_url: entry.permalink_url,
      format: 'markdown',
      state: state,
      date: entry.published_at.to_s,
      data: entry&.photos&.map { |p| URI.open(p.tumblr_url).path }
    }.compact

    response = tumblr.photo(tumblr_username, opts)
    raise response.to_s if response['errors'].present? || (response['status'].present? && response['status'] >= 400)

    # Save the Tumblr ID, which will be ephemeral if the post was queued in Tumblr.
    # (it'll change when the post gets published.)
    entry.tumblr_id = response['id_string']
    entry.save
    entry.track_recently_shared('Tumblr')

    # Enqueue a job to fetch and store the Tumblr post's metadata
    # (the new Tumblr ID if and when it changes, and the reblog key.)
    TumblrMetadataWorker.perform_async(entry.id)
  end
end
