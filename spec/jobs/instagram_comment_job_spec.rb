require 'rails_helper'

RSpec.describe InstagramCommentJob, type: :worker do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, blog: blog, user: user) }
  let!(:instagram_account) { create(:social_account, :instagram, user: user) }

  before do
    allow(Rails.env).to receive(:production?).and_return(true)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('INSTAGRAM_APP_ID').and_return('app_id')
    allow(ENV).to receive(:[]).with('INSTAGRAM_APP_SECRET').and_return('app_secret')
  end

  describe '#perform' do
    it 'returns early in non-production environment' do
      allow(Rails.env).to receive(:production?).and_return(false)
      expect(Instagram).not_to receive(:new)
      described_class.new.perform(entry.id, '12345')
    end

    it 'returns early when credentials are missing' do
      allow(ENV).to receive(:[]).with('INSTAGRAM_APP_ID').and_return(nil)
      expect(Instagram).not_to receive(:new)
      described_class.new.perform(entry.id, '12345')
    end

    it 'returns early when comment is blank' do
      allow_any_instance_of(Entry).to receive(:instagram_hashtags).and_return(nil)
      expect(Instagram).not_to receive(:new)
      described_class.new.perform(entry.id, '12345')
    end

    it 'returns early when user has no connected Instagram account' do
      instagram_account.destroy
      allow_any_instance_of(Entry).to receive(:instagram_hashtags).and_return('#nature #photo')
      expect(Instagram).not_to receive(:new)
      described_class.new.perform(entry.id, '12345')
    end

    it 'posts comment to Instagram' do
      instagram = instance_double(Instagram)
      allow(Instagram).to receive(:new).and_return(instagram)
      allow_any_instance_of(Entry).to receive(:instagram_hashtags).and_return('#nature #photo')

      expect(instagram).to receive(:post_comment).with(
        media_id: '12345',
        message: '#nature #photo'
      )

      described_class.new.perform(entry.id, '12345')
    end

    it 'initializes Instagram with the connected social account' do
      instagram = instance_double(Instagram)
      allow(instagram).to receive(:post_comment)
      allow_any_instance_of(Entry).to receive(:instagram_hashtags).and_return('#nature #photo')

      expect(Instagram).to receive(:new).with(
        app_id: 'app_id',
        app_secret: 'app_secret',
        social_account: instagram_account
      ).and_return(instagram)

      described_class.new.perform(entry.id, '12345')
    end
  end
end
