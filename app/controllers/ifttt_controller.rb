class IftttController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :domain_redirect

  def instagram
    if params[:token] != ENV['ifttt_webhook_token']
      render plain: 'No', status: 401
    else
      entry = Entry.published.first

      attachment = {
        fallback: 'New photo on Instagram!',
        text: params[:caption],
        image_url: params[:source_url],
        actions: [{
          type: 'button',
          text: 'Open in Instagram',
          url: params[:url]
        }]
      }

      SlackJob.perform_later(attachments: [attachment])
      SlackJob.perform_later(text: entry.instagram_hashtags)
      render plain: 'OK'
    end
  end
end
