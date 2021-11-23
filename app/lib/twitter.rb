require 'oauth'
require 'json'
require 'typhoeus'
require 'oauth/request_proxy/typhoeus_request'
require 'open-uri'

class Twitter

  def initialize
    consumer_key = ENV['twitter_consumer_key']
    consumer_secret = ENV['twitter_consumer_secret']
    access_token = ENV['twitter_access_token']
    access_token_secret = ENV['twitter_access_token_secret']

    consumer = OAuth::Consumer.new(consumer_key, consumer_secret, site: 'https://api.twitter.com', authorize_path: '/oauth/authenticate', debug_output: false)
    token = OAuth::ConsumerToken.new(consumer, access_token, access_token_secret)
    @oauth_params = { consumer: consumer, token: token }
  end

  def tweet(payload)
    url = "https://api.twitter.com/2/tweets"

    media_ids = if payload[:photos].present?
      payload[:photos].map { |p| upload_photo(p) }
    else
      []
    end
    body = {
      text: payload[:text],
    }

    body[:media] = { media_ids: media_ids } if media_ids.present?
    response = request(body: body, url: url)
  end

  def tweet_v1(payload)
    url = "https://api.twitter.com/1.1/statuses/update.json"

    media_ids = if payload[:photos].present?
      payload[:photos].map { |p| upload_photo(p) }
    else
      []
    end

    params = {
      status: payload[:text]
    }

    params[:media_ids] = media_ids.join(',') if media_ids.present?
    response = request(params: params, url: url)
  end

  private

  def upload_photo(photo)
    media = URI.open(photo[:url])
    response = upload_media(URI.open(photo[:url]))
    media_id = response["media_id_string"]
    set_alt_text(media_id, photo[:alt_text])
    media_id
  end

  def set_alt_text(media_id, alt_text)
    body = {
      media_id: media_id,
      alt_text: {
        text: alt_text
      }
    }
    request(body: body, url: 'https://upload.twitter.com/1.1/media/metadata/create.json')
  end

  def request(url:, body: nil, params: nil, method: :post, headers: { "content-type": "application/json; charset=UTF-8" })
    options = {
      method: method,
      headers: headers,
      body: body.to_json,
      params: params
    }.compact

    request = Typhoeus::Request.new(url, options)
    oauth_helper = OAuth::Client::Helper.new(request, @oauth_params.merge(request_uri: url))
    authorization = oauth_helper.header
    request.options[:headers].merge!({ "Authorization": authorization })
    response = request.run
    if response.success?
      begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        ""
      end
    else
      raise response.body
    end
  end

  def upload_media(media)
    url = 'https://upload.twitter.com/1.1/media/upload.json'
    options = {
      method: :post,
      headers: { 'content-type': 'multipart/form-data' }
    }

    request = Typhoeus::Request.new(url, options)
    oauth_helper = OAuth::Client::Helper.new(request, @oauth_params.merge(request_uri: url))
    authorization = oauth_helper.header
    request.options[:headers].merge!({ "Authorization": authorization })
    request.options[:body] = { media: media }
    response = request.run
    if response.success?
      begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        ""
      end
    else
      raise response.body
    end
  end
end