FactoryBot.define do
  factory :territory do
    sequence(:slug) { |n| "territory-#{n}" }
    sequence(:name) { |n| "Territory #{n}" }
  end
end
