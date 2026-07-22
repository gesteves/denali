require 'digest'

# Invalidates cached HTML at Cloudflare's edge by purging cache tags.
#
# Pages are cached for CACHE_TTL (a day), which is far longer than the old
# five-minute window; purging is what actually keeps them fresh, and the TTL is
# only a backstop for a purge that never lands. See CacheTags for the vocabulary
# and ApplicationController#set_cache_tags for where tags are attached.
class CachePurgeJob < ApplicationJob
  sidekiq_options queue: 'high'

  PURGE_URL = 'https://api.cloudflare.com/client/v4/zones/%s/purge_cache'

  # Cloudflare accepts at most 30 tags per purge request on non-Enterprise plans.
  MAX_TAGS_PER_REQUEST = 30

  # A photo save touches its entry, and a freshly uploaded entry sets off half a
  # dozen jobs (EXIF, alt text, colors, geocoding, native lands, blurhash) that
  # each save a photo. Without a window, one upload would fire a dozen purges.
  DEBOUNCE = 30.seconds

  # Enqueues a purge once per tag set per DEBOUNCE window, on the trailing edge
  # so the burst has settled by the time it runs. Use this for edits. Publishing
  # calls perform_async directly instead: it happens once, and waiting half a
  # minute for a new post to appear is worse than the duplicate purge it avoids.
  def self.enqueue(*tags)
    tags = tags.flatten.compact.uniq
    return if tags.empty?

    key = "cache-purge/#{Digest::MD5.hexdigest(tags.sort.join(','))}"
    return unless Rails.cache.write(key, true, unless_exist: true, expires_in: DEBOUNCE)

    perform_in(DEBOUNCE, *tags)
  end

  def perform(*tags)
    return if !Rails.env.production?
    return if ENV['CLOUDFLARE_ZONE_ID'].blank? || ENV['CLOUDFLARE_API_TOKEN'].blank?

    tags = tags.flatten.compact.uniq
    return if tags.empty?

    tags.each_slice(MAX_TAGS_PER_REQUEST) { |batch| purge(batch) }
  end

  private

  def purge(tags)
    logger.info "[CachePurge] Purging tags: #{tags.join(', ')}"

    response = HTTParty.post(
      format(PURGE_URL, ENV['CLOUDFLARE_ZONE_ID']),
      body: { tags: tags }.to_json,
      headers: {
        'Authorization' => "Bearer #{ENV['CLOUDFLARE_API_TOKEN']}",
        'Content-Type' => 'application/json'
      },
      timeout: 15
    )

    body = JSON.parse(response.body) rescue {}
    return if response.code < 400 && body['success']

    raise "Failed to purge #{tags.join(', ')}: #{body.dig('errors')&.map { |e| e['message'] }&.join('; ') || response.body}"
  end
end
