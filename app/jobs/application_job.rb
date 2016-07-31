class ApplicationJob < ActiveJob::Base
  include ActionView::Helpers::TextHelper
  self.queue_adapter = :resque
end
