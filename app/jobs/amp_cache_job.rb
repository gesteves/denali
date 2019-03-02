class AmpCacheJob < ApplicationJob

  def perform(entry)
    return if !Rails.env.production? || ENV['google_amp_cache_private_key_url'].blank?
    caches = get_cache_prefixes

    timestamp = Time.current.to_i
    domain = Rails.application.routes.default_url_options[:host]
    path = "/update-cache/c/s/#{domain}#{entry.amp_path}?amp_action=flush&amp_ts=#{timestamp}"
    signature = Base64.urlsafe_encode64(sign(path))
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
    if response.code >= 400
      logger.tagged('AMP') { logger.error { "Update cache request to #{cache} responded with #{response.code}" } }
    end
  end

  def sign(path)
    keypair = OpenSSL::PKey::RSA.new(HTTParty.get(ENV['google_amp_cache_private_key_url']).body)
    keypair.sign(OpenSSL::Digest::SHA256.new, path)
  end
end
