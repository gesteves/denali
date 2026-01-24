FactoryBot.define do
  factory :webhook do
    association :blog
    sequence(:url) { |n| "https://example.com/webhook/#{n}" }

    trait :ifttt do
      url { "https://maker.ifttt.com/trigger/new_post/with/key/abc123" }
    end

    trait :slack do
      url { "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX" }
    end

    trait :discord do
      url { "https://discord.com/api/webhooks/123456789/abcdefg" }
    end
  end
end
