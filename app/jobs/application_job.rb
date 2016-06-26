class ApplicationJob < ActiveJob::Base
  include ActionView::Helpers::TextHelper

  rescue_from Exception do |e|
    Raven.capture_exception(e)
    raise e
  end
end
