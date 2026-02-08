require 'rails_helper'

RSpec.describe FlickrUpdateJob, type: :worker do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }
  let!(:flickr_account) { create(:social_account, :flickr, user: user) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
  let(:photo) { entry.photos.first }

  before do
    attach_image_to_photo(photo)
    allow(Rails.env).to receive(:production?).and_return(true)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('FLICKR_CONSUMER_KEY').and_return('consumer_key')
    allow(ENV).to receive(:[]).with('FLICKR_CONSUMER_SECRET').and_return('consumer_secret')
  end

  describe '#perform' do
    it 'returns early in non-production environment' do
      allow(Rails.env).to receive(:production?).and_return(false)
      expect(FlickRaw::Flickr).not_to receive(:new)
      described_class.new.perform(photo.id, 'flickr_123')
    end

    it 'returns early when consumer credentials are missing' do
      allow(ENV).to receive(:[]).with('FLICKR_CONSUMER_KEY').and_return(nil)
      expect(FlickRaw::Flickr).not_to receive(:new)
      described_class.new.perform(photo.id, 'flickr_123')
    end

    it 'returns early when user has no Flickr account' do
      flickr_account.destroy
      expect(FlickRaw::Flickr).not_to receive(:new)
      described_class.new.perform(photo.id, 'flickr_123')
    end

    it 'updates photo metadata on Flickr using connected account' do
      flickr = double('FlickRaw::Flickr')
      photos_api = double('photos')
      allow(FlickRaw::Flickr).to receive(:new).and_return(flickr)
      allow(flickr).to receive(:access_token=)
      allow(flickr).to receive(:access_secret=)
      allow(flickr).to receive(:photos).and_return(photos_api)

      expect(photos_api).to receive(:setMeta).with(hash_including(photo_id: 'flickr_123'))
      expect(photos_api).to receive(:setTags).with(hash_including(photo_id: 'flickr_123'))

      described_class.new.perform(photo.id, 'flickr_123')
    end
  end
end
