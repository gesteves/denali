FactoryBot.define do
  factory :mastodon_app do
    sequence(:instance_url) { |n| "https://mastodon#{n}.social" }
    sequence(:client_id) { |n| "client_id_#{n}" }
    client_secret { SecureRandom.alphanumeric(32) }
  end
end
