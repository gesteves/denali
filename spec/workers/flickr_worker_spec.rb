require 'rails_helper'

RSpec.describe FlickrWorker, type: :worker do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
  let(:photo) { entry.photos.first }

  before do
    attach_image_to_photo(photo)
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
      described_class.new.perform(photo.id)
    end

    it 'returns early when credentials are missing' do
      allow(ENV).to receive(:[]).with('FLICKR_CONSUMER_KEY').and_return(nil)
      expect(FlickRaw::Flickr).not_to receive(:new)
      described_class.new.perform(photo.id)
    end

    it 'uploads photo to Flickr' do
      flickr = instance_double(FlickRaw::Flickr)
      allow(FlickRaw::Flickr).to receive(:new).and_return(flickr)
      allow(flickr).to receive(:access_token=)
      allow(flickr).to receive(:access_secret=)
      allow(flickr).to receive(:upload_photo).and_return('123456')
      allow(URI).to receive(:open).and_return(double(path: '/tmp/photo.jpg'))
      allow_any_instance_of(Entry).to receive(:flickr_groups).and_return([])
      allow_any_instance_of(Entry).to receive(:flickr_albums).and_return([])

      expect(flickr).to receive(:upload_photo)
      described_class.new.perform(photo.id)
    end

    it 'enqueues group and album workers after upload' do
      flickr = instance_double(FlickRaw::Flickr)
      allow(FlickRaw::Flickr).to receive(:new).and_return(flickr)
      allow(flickr).to receive(:access_token=)
      allow(flickr).to receive(:access_secret=)
      allow(flickr).to receive(:upload_photo).and_return('123456')
      allow(URI).to receive(:open).and_return(double(path: '/tmp/photo.jpg'))
      allow_any_instance_of(Entry).to receive(:flickr_groups).and_return(['https://flickr.com/groups/test'])
      allow_any_instance_of(Entry).to receive(:flickr_albums).and_return(['https://flickr.com/albums/test'])

      described_class.new.perform(photo.id)

      expect(FlickrGroupWorker.jobs.size).to eq(1)
      expect(FlickrAlbumWorker.jobs.size).to eq(1)
    end
  end
end
