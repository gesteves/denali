require 'rails_helper'

RSpec.describe InstagramJob, type: :worker do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
  let!(:instagram_account) { create(:social_account, :instagram, user: user) }

  before do
    entry.photos.each { |p| attach_image_to_photo(p) }
    allow(Rails.env).to receive(:production?).and_return(true)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('INSTAGRAM_APP_ID').and_return('app_id')
    allow(ENV).to receive(:[]).with('INSTAGRAM_APP_SECRET').and_return('app_secret')
  end

  describe '#perform' do
    it 'returns early in non-production environment' do
      allow(Rails.env).to receive(:production?).and_return(false)
      expect(Instagram).not_to receive(:new)
      described_class.new.perform(entry.id, 'Test caption')
    end

    it 'returns early when credentials are missing' do
      allow(ENV).to receive(:[]).with('INSTAGRAM_APP_ID').and_return(nil)
      expect(Instagram).not_to receive(:new)
      described_class.new.perform(entry.id, 'Test caption')
    end

    it 'returns early for non-photo entries' do
      text_entry = create(:entry, :published, blog: blog, user: user)
      expect(Instagram).not_to receive(:new)
      described_class.new.perform(text_entry.id, 'Test caption')
    end

    it 'returns early when user has no connected Instagram account' do
      instagram_account.destroy
      expect(Instagram).not_to receive(:new)
      described_class.new.perform(entry.id, 'Test caption')
    end

    it 'posts to Instagram and updates entry' do
      instagram = instance_double(Instagram)
      allow(Instagram).to receive(:new).and_return(instagram)
      allow(instagram).to receive(:post).and_return({ 'id' => '12345' })
      allow(entry.photos.first).to receive(:instagram_location_id).and_return(nil)

      expect(instagram).to receive(:post).with(
        hash_including(caption: 'Test caption')
      )

      described_class.new.perform(entry.id, 'Test caption')
      entry.reload
      expect(entry.last_shared_on_instagram_at).not_to be_nil
      expect(entry.instagram_shares_count).to eq(1)
    end

    it 'initializes Instagram with the connected social account' do
      instagram = instance_double(Instagram)
      allow(instagram).to receive(:post).and_return({ 'id' => '12345' })

      expect(Instagram).to receive(:new).with(
        app_id: 'app_id',
        app_secret: 'app_secret',
        social_account: instagram_account
      ).and_return(instagram)

      described_class.new.perform(entry.id, 'Test caption')
    end

    it 'enqueues comment worker when post has hashtags' do
      instagram = instance_double(Instagram)
      allow(Instagram).to receive(:new).and_return(instagram)
      allow(instagram).to receive(:post).and_return({ 'id' => '12345' })
      allow_any_instance_of(Entry).to receive(:instagram_hashtags).and_return('#nature #photo')

      described_class.new.perform(entry.id, 'Test caption')

      expect(InstagramCommentJob.jobs.size).to eq(1)
    end

    it 'does not enqueue comment worker when no hashtags' do
      instagram = instance_double(Instagram)
      allow(Instagram).to receive(:new).and_return(instagram)
      allow(instagram).to receive(:post).and_return({ 'id' => '12345' })
      allow_any_instance_of(Entry).to receive(:instagram_hashtags).and_return(nil)

      described_class.new.perform(entry.id, 'Test caption')

      expect(InstagramCommentJob.jobs.size).to eq(0)
    end
  end
end
