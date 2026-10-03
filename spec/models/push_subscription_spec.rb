require 'rails_helper'

RSpec.describe PushSubscription, type: :model do
  describe 'associations' do
    it { should belong_to(:blog) }
  end

  describe 'validations' do
    subject { create(:push_subscription) }

    it { should validate_presence_of(:endpoint) }
    it { should validate_uniqueness_of(:endpoint) }
    it { should validate_presence_of(:p256dh) }
    it { should validate_presence_of(:auth) }

    it 'validates endpoint is a valid URL' do
      subscription = build(:push_subscription, endpoint: 'not-a-url')
      expect(subscription).not_to be_valid
      expect(subscription.errors[:endpoint]).to include('is not a valid URL')
    end

    it 'rejects plain HTTP URLs' do
      subscription = build(:push_subscription, endpoint: 'http://fcm.googleapis.com/fcm/send/abc')
      expect(subscription).not_to be_valid
      expect(subscription.errors[:endpoint]).to include('is not a valid URL')
    end

    %w[
      https://fcm.googleapis.com/fcm/send/abc
      https://updates.push.services.mozilla.com/wpush/v2/abc
      https://web.push.apple.com/abc
      https://wns2-by3p.notify.windows.com/w/?token=abc
    ].each do |endpoint|
      it "accepts push service endpoint #{endpoint}" do
        expect(build(:push_subscription, endpoint: endpoint)).to be_valid
      end
    end

    %w[
      https://example.com/push
      https://fcm.googleapis.com.evil.com/push
      https://169.254.169.254/latest/meta-data
      https://my-app.internal/push
    ].each do |endpoint|
      it "rejects non-push-service endpoint #{endpoint}" do
        subscription = build(:push_subscription, endpoint: endpoint)
        expect(subscription).not_to be_valid
        expect(subscription.errors[:endpoint]).to include('is not a known push service')
      end
    end
  end

  describe 'factory' do
    it 'creates a valid push subscription' do
      subscription = create(:push_subscription)
      expect(subscription).to be_valid
    end
  end

  describe '.deliver_all' do
    let(:blog) { create(:blog) }
    let(:user) { create(:user) }
    let(:entry) { create(:entry, blog: blog, user: user) }

    it 'enqueues PushNotificationJob for each subscription' do
      create_list(:push_subscription, 3, blog: blog)

      expect {
        PushSubscription.deliver_all(entry)
      }.to change(PushNotificationJob.jobs, :size).by(3)
    end
  end
end
