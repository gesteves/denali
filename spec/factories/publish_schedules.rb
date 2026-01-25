FactoryBot.define do
  factory :publish_schedule do
    association :blog
    # Use a sequence that avoids already-used hours
    sequence(:hour) do |n|
      used_hours = PublishSchedule.pluck(:hour)
      available_hours = (0..23).to_a - used_hours
      if available_hours.any?
        available_hours.first
      else
        n % 24  # Fallback, might cause uniqueness error
      end
    end
  end
end
