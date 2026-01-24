FactoryBot.define do
  factory :park do
    sequence(:slug) { |n| "park-#{n}" }
    sequence(:code) { |n| "PARK#{n}" }
    sequence(:full_name) { |n| "National Park #{n}" }
    sequence(:display_name) { |n| "Park #{n}" }
    designation { "National Park" }

    trait :with_instagram_location do
      instagram_location_id { "123456789" }
    end

    trait :with_threads_location do
      threads_location_id { "987654321" }
    end
  end
end
