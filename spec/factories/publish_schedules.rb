FactoryBot.define do
  factory :publish_schedule do
    association :blog
    hour { nil } # Must be set explicitly since it's globally unique
  end
end
