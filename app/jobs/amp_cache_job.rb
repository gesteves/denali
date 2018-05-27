class AmpCacheJob < ApplicationJob

  def perform(entry)
    return if !Rails.env.production? || ENV['google_amp_cache_private_key_url'].blank?
    caches = get_cache_prefixes

    timestamp = Time.now.to_i
    domain = entry.blog.domain
    path = "/update-cache/c/s/#{domain}#{entry.amp_path}?amp_action=flush&amp_ts=#{timestamp}"
    signature = Base64.urlsafe_encode64(sign(path))
    logger.info "[AMP Cache] Preparing update cache request for #{path}"
    caches.map { |cache| update(cache, domain, path, signature) }
  end

  private

  def get_cache_prefixes
    response = HTTParty.get('https://cdn.ampproject.org/caches.json')
    caches = begin
      JSON.parse(response.body)['caches']
    rescue
      []
    end
    caches.map { |c| c['updateCacheApiDomainSuffix'] }
  end

  def update(cache, domain, path, signature)
    url = "https://#{domain.parameterize}.#{cache}#{path}&amp_url_signature=#{signature}"
    response = HTTParty.get(url)
    logger.info "[AMP Cache] Update cache request to #{cache} responded with #{response.code}"
  end

  def sign(path)
    keypair = OpenSSL::PKey::RSA.new(HTTParty.get(ENV['google_amp_cache_private_key_url']).body)
    keypair.sign(OpenSSL::Digest::SHA256.new, path)
  end
end
