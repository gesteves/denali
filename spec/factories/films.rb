FactoryBot.define do
  factory :film do
    sequence(:slug) { |n| "film-#{n}" }
    make { "Kodak" }
    sequence(:model) { |n| "Portra #{400 + n}" }
    sequence(:display_name) { |n| "Kodak Portra #{400 + n}" }
  end
end
