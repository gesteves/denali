module Admin::PublishSchedulesHelper

  def pretty_hour(hour, show_timezone = false)
    pretty_hour = if hour == 0
      "12:00 am"
    elsif hour <= 12
      "#{hour}:00 am"
    else
      "#{hour - 12}:00 pm"
    end
    show_timezone ? "#{pretty_hour} – #{Rails.application.config.time_zone}" : pretty_hour
  end
end
