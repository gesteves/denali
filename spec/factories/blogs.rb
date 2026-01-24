FactoryBot.define do
  factory :blog do
    sequence(:name) { |n| "Blog #{n}" }
    about { "This is a blog about photography." }
    posts_per_page { 20 }
    show_related_entries { true }
    time_zone { "Eastern Time (US & Canada)" }
  end
end
