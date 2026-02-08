require 'open-uri'
class ApplicationJob
  include Sidekiq::Job
  include ActionView::Helpers::TextHelper
  sidekiq_options queue: 'default'

  sidekiq_retry_in do |count, exception|
    case exception
    when UnprocessedPhotoError
      count + 1
    end
  end
end
