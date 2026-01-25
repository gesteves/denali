require 'rails_helper'

RSpec.describe FlickrAlbumWorker, type: :worker do
  before do
    allow(Rails.env).to receive(:production?).and_return(true)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('FLICKR_CONSUMER_KEY').and_return('consumer_key')
    allow(ENV).to receive(:[]).with('FLICKR_CONSUMER_SECRET').and_return('consumer_secret')
    allow(ENV).to receive(:[]).with('FLICKR_ACCESS_TOKEN').and_return('access_token')
    allow(ENV).to receive(:[]).with('FLICKR_ACCESS_TOKEN_SECRET').and_return('access_secret')
  end

  describe '#perform' do
    it 'returns early in non-production environment' do
      allow(Rails.env).to receive(:production?).and_return(false)
      expect(FlickRaw::Flickr).not_to receive(:new)
      described_class.new.perform('123456', 'https://flickr.com/albums/789')
    end

    it 'adds photo to album' do
      # Use double instead of instance_double since FlickRaw uses method_missing
      flickr = double('FlickRaw::Flickr')
      photosets = double('photosets')
      allow(FlickRaw::Flickr).to receive(:new).and_return(flickr)
      allow(flickr).to receive(:access_token=)
      allow(flickr).to receive(:access_secret=)
      allow(flickr).to receive(:photosets).and_return(photosets)

      expect(photosets).to receive(:addPhoto).with(photo_id: '123456', photoset_id: '789')
      expect(photosets).to receive(:reorderPhotos).with(photo_ids: '123456', photoset_id: '789')

      described_class.new.perform('123456', 'https://flickr.com/albums/789')
    end

    it 'handles FlickRaw errors gracefully' do
      flickr = double('FlickRaw::Flickr')
      photosets = double('photosets')
      allow(FlickRaw::Flickr).to receive(:new).and_return(flickr)
      allow(flickr).to receive(:access_token=)
      allow(flickr).to receive(:access_secret=)
      allow(flickr).to receive(:photosets).and_return(photosets)
      # FlickRaw::FailedResponse takes 3 args: code, msg, and method
      allow(photosets).to receive(:addPhoto).and_raise(FlickRaw::FailedResponse.new(1, 'Error', 'photosets.addPhoto'))

      expect { described_class.new.perform('123456', 'https://flickr.com/albums/789') }.not_to raise_error
    end
  end
end
