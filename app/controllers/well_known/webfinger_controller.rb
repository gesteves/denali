class WellKnown::WebfingerController < ApplicationController
  before_action :set_max_age

  def show
    request.format = 'json'
    @subject = params[:resource]
    logger.tagged("Webfinger") { logger.info "Webfinger request for #{@subject}" }
    username = @subject&.gsub(/^acct:/, '')&.split('@')&.first
    domain = @subject&.gsub(/^acct:/, '')&.split('@')&.last
    valid_domain = begin
      domain = PublicSuffix.parse(domain).domain
      site_domain = PublicSuffix.parse(ENV['DOMAIN']).domain
      domain == site_domain
    rescue
      false
    end
    @profile = Profile.find_by_username(username)
    raise ActiveRecord::RecordNotFound if @profile.blank? || !valid_domain
    respond_to do |format|
      format.json {
        @links = [
          {
            rel: 'http://webfinger.net/rel/profile-page',
            type: 'text/html',
            href: root_url
          },
          {
            rel: 'self',
            type: 'application/activity+json',
            href: activitypub_profile_url(user_id: @profile.user.id)
          }
        ]
        render
      }
    end
  end
end
