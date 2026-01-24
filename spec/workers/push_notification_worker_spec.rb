require 'rails_helper'

RSpec.describe PushNotificationWorker, type: :worker do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
  let(:push_subscription) { create(:push_subscription, blog: blog) }

  before do
    entry.photos.each { |p| attach_image_to_photo(p) }
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('VAPID_MAILTO_ADDRESS').and_return('test@example.com')
    allow(ENV).to receive(:[]).with('VAPID_PUBLIC_KEY').and_return('public_key')
    allow(ENV).to receive(:[]).with('VAPID_PRIVATE_KEY').and_return('private_key')
  end

  describe '#perform' do
    it 'sends push notification via WebPush' do
      expect(WebPush).to receive(:payload_send).with(
        hash_including(
          endpoint: push_subscription.endpoint,
          p256dh: push_subscription.p256dh,
          auth: push_subscription.auth
        )
      )

      described_class.new.perform(push_subscription.id, entry.id)
    end

    it 'includes correct message content' do
      expect(WebPush).to receive(:payload_send) do |args|
        message = JSON.parse(args[:message])
        expect(message['title']).to eq('New photo published')
        expect(message['body']).to eq(entry.plain_title)
        expect(message['url']).to include(entry.id.to_s)
      end

      described_class.new.perform(push_subscription.id, entry.id)
    end

    context 'with photoset entry' do
      let(:photoset_entry) { create(:entry, :published, :with_photos, blog: blog, user: user, photos_count: 3) }

      before do
        photoset_entry.photos.each { |p| attach_image_to_photo(p) }
      end

      it 'uses correct title for photosets' do
        expect(WebPush).to receive(:payload_send) do |args|
          message = JSON.parse(args[:message])
          expect(message['title']).to eq('New photos published')
        end

        described_class.new.perform(push_subscription.id, photoset_entry.id)
      end
    end

    context 'when subscription is invalid' do
      let(:mock_response) { instance_double('Net::HTTPResponse', body: 'error', code: '410') }

      it 'destroys the subscription on InvalidSubscription error' do
        # Ensure push_subscription exists before measuring count
        subscription_id = push_subscription.id
        entry_id = entry.id
        allow(WebPush).to receive(:payload_send).and_raise(WebPush::InvalidSubscription.new(mock_response, 'localhost'))

        expect {
          described_class.new.perform(subscription_id, entry_id)
        }.to change(PushSubscription, :count).by(-1)
      end

      it 'destroys the subscription on ExpiredSubscription error' do
        # Ensure push_subscription exists before measuring count
        subscription_id = push_subscription.id
        entry_id = entry.id
        allow(WebPush).to receive(:payload_send).and_raise(WebPush::ExpiredSubscription.new(mock_response, 'localhost'))

        expect {
          described_class.new.perform(subscription_id, entry_id)
        }.to change(PushSubscription, :count).by(-1)
      end
    end

    it 'raises error when push_subscription_id is invalid' do
      expect(WebPush).not_to receive(:payload_send)
      expect {
        described_class.new.perform(-1, entry.id)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
