class ApplicationJob < ActiveJob::Base
  include ActionView::Helpers::TextHelper
  self.queue_adapter = :resque unless Rails.env.test?
end
