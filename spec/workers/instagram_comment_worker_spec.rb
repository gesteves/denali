require 'rails_helper'

RSpec.describe InstagramCommentWorker, type: :worker do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, blog: blog, user: user) }

  before do
    allow(Rails.env).to receive(:production?).and_return(true)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('INSTAGRAM_APP_ID').and_return('app_id')
    allow(ENV).to receive(:[]).with('INSTAGRAM_APP_SECRET').and_return('app_secret')
    allow(ENV).to receive(:[]).with('INSTAGRAM_ACCESS_TOKEN').and_return('access_token')
    allow(ENV).to receive(:[]).with('INSTAGRAM_ACCOUNT_ID').and_return('account_id')
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
  end
end
