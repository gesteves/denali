FactoryBot.define do
  factory :blog do
    sequence(:name) { |n| "Blog #{n}" }
    about { "This is a blog about photography." }
    posts_per_page { 20 }
    show_related_entries { true }
    time_zone { "Eastern Time (US & Canada)" }

    # A blog that publishes to standard.site, with an account whose repo holds the records.
    trait :on_standard_site do
      standard_site_did { "did:plc:abc123" }
      standard_site_social_account { association :social_account, provider: 'bluesky' }
    end
  end
end
