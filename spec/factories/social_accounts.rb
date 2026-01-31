FactoryBot.define do
  factory :social_account do
    user
    provider { 'bluesky' }
    sequence(:uid) { |n| "did:plc:#{SecureRandom.alphanumeric(24)}" }
    sequence(:handle) { |n| "user#{n}.bsky.social" }
    access_token { SecureRandom.alphanumeric(32) }
    server_url { 'https://bsky.social' }
    connected_at { Time.current }

    trait :bluesky do
      provider { 'bluesky' }
      server_url { 'https://bsky.social' }
    end
  end
end
