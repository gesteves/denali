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

    trait :flickr do
      provider { 'flickr' }
      sequence(:uid) { |n| "#{n}@N00" }
      sequence(:handle) { |n| "flickruser#{n}" }
      access_token_secret { SecureRandom.alphanumeric(32) }
      server_url { nil }
    end

    trait :instagram do
      provider { 'instagram' }
      sequence(:uid) { |n| "#{n}" }
      sequence(:handle) { |n| "instagramuser#{n}" }
      server_url { nil }
    end

    trait :mastodon do
      provider { 'mastodon' }
      sequence(:uid) { |n| "#{n}" }
      sequence(:handle) { |n| "user#{n}@mastodon.social" }
      server_url { 'https://mastodon.social' }
    end

    trait :threads do
      provider { 'threads' }
      sequence(:uid) { |n| "#{n}" }
      sequence(:handle) { |n| "threadsuser#{n}" }
      server_url { nil }
    end
  end
end
