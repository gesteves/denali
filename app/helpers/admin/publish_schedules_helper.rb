module Admin::PublishSchedulesHelper

  def pretty_hour(hour)
    if hour == 0
      "12:00 am"
    elsif hour < 12
      "#{hour}:00 am"
    elsif hour == 12
      "12:00 pm"
    else
      "#{hour - 12}:00 pm"
    end
  end
end
