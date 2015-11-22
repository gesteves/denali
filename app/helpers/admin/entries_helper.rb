module Admin::EntriesHelper
  def publish_date_for_queued(entry, counter)
    days = if Time.now.utc.hour < 17
      counter
    else
      counter + 1
    end
    (Time.now + days.days).strftime('%A, %B %-d')
  end
end
