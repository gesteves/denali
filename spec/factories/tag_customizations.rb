FactoryBot.define do
  factory :tag_customization do
    association :blog
    tag_list { "landscape" }
    mastodon_hashtags { "#LandscapePhotography" }

    trait :with_bluesky_hashtags do
      bluesky_hashtags { "#LandscapePhotography #Nature" }
    end

    trait :with_instagram_hashtags do
      instagram_hashtags { "#landscape #photography #nature" }
    end

    trait :with_flickr_groups do
      flickr_groups { "https://www.flickr.com/groups/landscapes/" }
    end

    trait :with_flickr_albums do
      flickr_albums { "72157123456789012" }
    end

    trait :with_threads_topics do
      threads_topics { "Landscape Photography\nNature" }
    end
  end
end
