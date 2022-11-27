class WebfingerController < ApplicationController
  def show
    request.format = 'json'
    @subject = params[:resource]
    username = @subject&.gsub(/^acct:@?/, '')&.split('@')&.first
    domain = @subject&.gsub(/^acct:@?/, '')&.split('@')&.last
    valid_domain = begin
      domain = PublicSuffix.parse(domain).domain
      site_domain = PublicSuffix.parse(ENV['DOMAIN']).domain
      domain == site_domain
    rescue
      false
    end
    @profile = Profile.find_by_username(username)
    respond_to do |format|
      format.json {
        if @profile.blank? || !valid_domain
          render json: {}, status: 404
        else
          @links = [
            {
              rel: 'http://webfinger.net/rel/profile-page',
              type: 'text/html',
              href: profile_url(username: @profile.username)
            },
            {
              rel: 'self',
              type: 'application/activity+json',
              href: profile_url(username: @profile.username)
            }
          ]
          render template: 'activitypub/webfinger'
        end
      }
    end
  end
end
