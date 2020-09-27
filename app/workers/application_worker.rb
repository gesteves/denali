class ApplicationWorker
  include Sidekiq::Worker
  include ActionView::Helpers::TextHelper
  sidekiq_options queue: 'default'
end
