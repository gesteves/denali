FactoryBot.define do
  factory :entry do
    sequence(:title) { |n| "Entry #{n}" }
    body { "This is the entry body." }
    status { 'draft' }
    association :blog
    association :user
    show_location { true }

    trait :published do
      status { 'published' }
      published_at { Time.current }
      modified_at { Time.current }
    end

    trait :draft do
      status { 'draft' }
    end

    trait :queued do
      status { 'queued' }
      position { 1 }
    end

    trait :with_photo do
      after(:create) do |entry|
        create(:photo, entry: entry)
        entry.reload
      end
    end

    trait :with_photos do
      transient do
        photos_count { 3 }
      end

      after(:create) do |entry, evaluator|
        create_list(:photo, evaluator.photos_count, entry: entry)
        entry.reload
      end
    end

    trait :for_mastodon do
      post_to_mastodon { true }
    end

    trait :for_bluesky do
      post_to_bluesky { true }
    end

    trait :for_instagram do
      post_to_instagram { true }
    end

    trait :for_threads do
      post_to_threads { true }
    end

    trait :for_flickr do
      post_to_flickr { true }
    end

    trait :with_content_warning do
      content_warning { "Sensitive content" }
      is_sensitive { true }
    end
  end
end
