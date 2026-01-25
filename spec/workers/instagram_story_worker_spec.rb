require 'rails_helper'

RSpec.describe InstagramStoryWorker, type: :worker do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }

  before do
    entry.photos.each { |p| attach_image_to_photo(p) }
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
      described_class.new.perform(entry.id)
    end

    it 'returns early when credentials are missing' do
      allow(ENV).to receive(:[]).with('INSTAGRAM_APP_ID').and_return(nil)
      expect(Instagram).not_to receive(:new)
      described_class.new.perform(entry.id)
    end

    it 'returns early for non-photo entries' do
      text_entry = create(:entry, :published, blog: blog, user: user)
      expect(Instagram).not_to receive(:new)
      described_class.new.perform(text_entry.id)
    end

    it 'posts story to Instagram' do
      instagram = instance_double(Instagram)
      allow(Instagram).to receive(:new).and_return(instagram)
      allow_any_instance_of(Photo).to receive(:instagram_story_url).and_return('https://example.com/photo.jpg')

      expect(instagram).to receive(:post_story).with(
        hash_including(photo_url: 'https://example.com/photo.jpg')
      )

      described_class.new.perform(entry.id)
    end

    it 'passes crop parameter to photo URL' do
      instagram = instance_double(Instagram)
      allow(Instagram).to receive(:new).and_return(instagram)
      allow(instagram).to receive(:post_story)

      expect_any_instance_of(Photo).to receive(:instagram_story_url).with(crop: true)
      described_class.new.perform(entry.id, true)
    end
  end
end
