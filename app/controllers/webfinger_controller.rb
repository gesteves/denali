class WebfingerController < ApplicationController
  def show
    subject = params[:resource]
    username = params[:resource]&.gsub(/^acct:@?/, '')&.split('@')&.first
    domain = params[:resource]&.gsub(/^acct:@?/, '')&.split('@')&.last
    site_domain = PublicSuffix.parse(ENV['DOMAIN']).domain
    profile = Profile.find_by_username(username)
    if profile.present? && domain == site_domain
      response = {
        subject: subject,
        links: [
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
