FactoryBot.define do
  factory :photo do
    association :entry
    position { 1 }

    trait :with_image do
      after(:build) do |photo|
        photo.image.attach(
          io: File.open(Rails.root.join('spec/fixtures/images/rusty.jpg')),
          filename: 'rusty.jpg',
          content_type: 'image/jpeg'
        )
      end
    end

    trait :with_exif do
      focal_length { 50 }
      f_number { 2.8 }
      exposure { '1/250' }
      iso { 400 }
      taken_at { 1.week.ago }
    end

    trait :with_location do
      latitude { 38.8977 }
      longitude { -77.0365 }
      country { 'United States' }
      administrative_area { 'District of Columbia' }
      locality { 'Washington' }
    end

    trait :with_camera do
      association :camera
    end

    trait :with_lens do
      association :lens
    end

    trait :with_film do
      association :film
    end

    trait :with_park do
      association :park
    end

    trait :color do
      color { true }
      black_and_white { false }
    end

    trait :black_and_white do
      color { false }
      black_and_white { true }
    end

    trait :with_alt_text do
      alt_text { "A beautiful landscape photograph" }
      alt_text_needs_review { false }
    end

    trait :needs_alt_text_review do
      alt_text { "Auto-generated alt text" }
      alt_text_needs_review { true }
    end

    trait :with_blurhash do
      blurhash { "LEHV6nWB2yk8pyo0adR*.7kCMdnj" }
    end

    trait :vertical do
      after(:build) do |photo|
        allow(photo).to receive(:width).and_return(1000)
        allow(photo).to receive(:height).and_return(1500)
      end
    end

    trait :horizontal do
      after(:build) do |photo|
        allow(photo).to receive(:width).and_return(1500)
        allow(photo).to receive(:height).and_return(1000)
      end
    end

    trait :square do
      after(:build) do |photo|
        allow(photo).to receive(:width).and_return(1000)
        allow(photo).to receive(:height).and_return(1000)
      end
    end
  end
end
