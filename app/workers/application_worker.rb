require 'open-uri'
class ApplicationWorker
  include Sidekiq::Worker
  include ActionView::Helpers::TextHelper
  sidekiq_options queue: 'default'

  sidekiq_retry_in do |count, exception|
    case exception
    when UnprocessedPhotoError
      count + 1
    end
  end
end
