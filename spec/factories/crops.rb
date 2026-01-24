FactoryBot.define do
  factory :crop do
    association :photo
    x { 0.1 }
    y { 0.1 }
    width { 0.8 }
    height { 0.8 }
    aspect_ratio { "1:1" }

    trait :instagram do
      aspect_ratio { "4:5" }
      x { 0.0 }
      y { 0.1 }
      width { 1.0 }
      height { 0.8 }
    end

    trait :facebook do
      aspect_ratio { "1200:630" }
      x { 0.0 }
      y { 0.15 }
      width { 1.0 }
      height { 0.7 }
    end

    trait :story do
      aspect_ratio { "9:16" }
      x { 0.2 }
      y { 0.0 }
      width { 0.6 }
      height { 1.0 }
    end
  end
end
