require 'net/http'
class YoJob < ActiveJob::Base
  include Addressable

  queue_as :default

  def perform(entry)
    Net::HTTP.post_form(URI.parse('https://api.justyo.co/yoall/'), { api_token: ENV['yo_api_token'], link: permalink_url(entry) })
  end
end
