FactoryBot.define do
  factory :photo_territory do
    association :photo
    association :territory
  end
end
