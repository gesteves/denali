module Admin::EntriesHelper
  def new_queue_date
    last_in_queue = Entry.queued.last.try(:publish_date_for_queued) || Time.now
    last_in_queue + 1.day
  end
end
