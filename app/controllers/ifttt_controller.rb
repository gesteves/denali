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
        pretext: 'New photo on Instagram:',
        title: truncate(params[:caption], length: 100),
        title_link: params[:url],
        image_url: params[:source_url]
      }

      SlackJob.perform_later(attachments: [attachment])
      SlackJob.perform_later(text: entry.instagram_hashtags)
      render plain: 'OK'
    end
  end
end
