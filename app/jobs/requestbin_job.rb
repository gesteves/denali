class RequestbinJob < ApplicationJob
  queue_as :default

  def perform(entry)
    HTTParty.post('http://requestb.in/s3dg3us3', body: { url: entry.permalink_url, time: Time.now.to_s, env: Rails.env })
  end

end
