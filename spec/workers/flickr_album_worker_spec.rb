require 'rails_helper'

RSpec.describe FlickrAlbumWorker, type: :worker do
  let(:user) { create(:user) }
  let!(:flickr_account) { create(:social_account, :flickr, user: user) }

  before do
    allow(Rails.env).to receive(:production?).and_return(true)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('FLICKR_CONSUMER_KEY').and_return('consumer_key')
    allow(ENV).to receive(:[]).with('FLICKR_CONSUMER_SECRET').and_return('consumer_secret')
  end

  describe '#perform' do
    it 'returns early in non-production environment' do
      allow(Rails.env).to receive(:production?).and_return(false)
      expect(FlickRaw::Flickr).not_to receive(:new)
      described_class.new.perform('123456', 'https://flickr.com/albums/789', user.id)
    end

    it 'returns early when user has no Flickr account' do
      flickr_account.destroy
      expect(FlickRaw::Flickr).not_to receive(:new)
      described_class.new.perform('123456', 'https://flickr.com/albums/789', user.id)
    end

    it 'returns early when user_id is not provided' do
      expect(FlickRaw::Flickr).not_to receive(:new)
      described_class.new.perform('123456', 'https://flickr.com/albums/789')
    end

    it 'adds photo to album using connected account' do
      flickr = double('FlickRaw::Flickr')
      photosets = double('photosets')
      allow(FlickRaw::Flickr).to receive(:new).and_return(flickr)
      allow(flickr).to receive(:access_token=)
      allow(flickr).to receive(:access_secret=)
      allow(flickr).to receive(:photosets).and_return(photosets)

      expect(photosets).to receive(:addPhoto).with(photo_id: '123456', photoset_id: '789')
      expect(photosets).to receive(:reorderPhotos).with(photo_ids: '123456', photoset_id: '789')

      described_class.new.perform('123456', 'https://flickr.com/albums/789', user.id)
    end

    it 'handles FlickRaw errors gracefully' do
      flickr = double('FlickRaw::Flickr')
      photosets = double('photosets')
      allow(FlickRaw::Flickr).to receive(:new).and_return(flickr)
      allow(flickr).to receive(:access_token=)
      allow(flickr).to receive(:access_secret=)
      allow(flickr).to receive(:photosets).and_return(photosets)
      allow(photosets).to receive(:addPhoto).and_raise(FlickRaw::FailedResponse.new(1, 'Error', 'photosets.addPhoto'))

      expect { described_class.new.perform('123456', 'https://flickr.com/albums/789', user.id) }.not_to raise_error
    end
  end
end
