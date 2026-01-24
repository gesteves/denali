FactoryBot.define do
  factory :lens do
    sequence(:slug) { |n| "lens-#{n}" }
    make { "Canon" }
    sequence(:model) { |n| "EF #{24 + n}mm f/1.4L USM" }
    sequence(:display_name) { |n| "Canon EF #{24 + n}mm f/1.4L USM" }
  end
end
