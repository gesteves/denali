class WebfingerController < ApplicationController
  def show
    subject = params[:resource]
    username = params[:resource]&.gsub(/^acct:@?/, '')&.split('@')&.first

    domain = params[:resource]&.gsub(/^acct:@?/, '')&.split('@')&.last
    valid_domain = begin
      domain = PublicSuffix.parse(domain).domain
      site_domain = PublicSuffix.parse(ENV['DOMAIN']).domain
      domain == site_domain
    rescue
      false
    end
    profile = Profile.find_by_username(username)
    if profile.present? && valid_domain
      response = {
        subject: subject,
        links: [
          {
            rel: 'http://webfinger.net/rel/profile-page',
            type: 'text/html',
            href: profile_url(username: profile.username)
          },
          {
            rel: 'self',
            type: 'application/activity+json',
            href: profile_url(username: profile.username)
          }
        ]
      }
      render json: response
    else
      render json: {}, status: 404
    end
  end
end
