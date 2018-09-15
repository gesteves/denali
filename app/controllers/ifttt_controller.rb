class IftttController < ApplicationController
  include ActionView::Helpers::TextHelper

  skip_before_action :verify_authenticity_token
  skip_before_action :domain_redirect

  def instagram
    if params[:token] != ENV['ifttt_webhook_token']
      render plain: 'No', status: 401
    else
      entry = Entry.published.first

      attachment = {
        fallback: "Instagram: #{truncate(params[:caption], length: 100)}",
        title: params[:caption].split("\n").first,
        title_link: params[:url],
        image_url: params[:source_url],
        color: '#c13584',
        author_name: 'Instagram',
        author_icon: ActionController::Base.helpers.asset_url('instagram-logo.png')
      }

      ts = begin
        DateTime.strptime(params[:created_at], '%B %d, %Y at %I:%M%p').to_i
      rescue
        nil
      end

      attachment[:ts] = ts if ts.present?

      SlackJob.perform_later(attachments: [attachment])
      SlackJob.perform_later(text: entry.instagram_hashtags)
      render plain: 'OK'
    end
  end
end
