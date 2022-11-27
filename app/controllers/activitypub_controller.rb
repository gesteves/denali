class ActivitypubController < ApplicationController
  before_action :set_json_format
  skip_before_action :is_repeat_visit?
  helper_method :is_activitystream_request?

  def is_activitystream_request?
    valid = ['application/ld+json', 'application/activity+json', 'profile="https://www.w3.org/ns/activitystreams"']
    values = request.headers['Accept']&.split(/[;,]/)&.map { |h| h.strip }
    return false if values.blank?
    (values & valid).present?
  end

  def set_json_format
    request.format = 'json'
  end
end
