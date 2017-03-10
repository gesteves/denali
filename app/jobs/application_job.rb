class ApplicationJob < ActiveJob::Base
  include ActionView::Helpers::TextHelper

  self.queue_adapter = :resque unless Rails.env.test?

  rescue_from(StandardError) do |exception|
    Raven.capture_exception(exception)
  end
end
