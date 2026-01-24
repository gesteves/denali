FactoryBot.define do
  factory :camera do
    sequence(:slug) { |n| "camera-#{n}" }
    make { "Canon" }
    sequence(:model) { |n| "EOS #{n}D" }
    sequence(:display_name) { |n| "Canon EOS #{n}D" }
    is_phone { false }

    trait :phone do
      make { "Apple" }
      model { "iPhone 15 Pro" }
      display_name { "Apple iPhone 15 Pro" }
      is_phone { true }
    end
  end
end
