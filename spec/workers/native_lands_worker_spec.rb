require 'rails_helper'

RSpec.describe NativeLandsWorker, type: :worker do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
  let(:photo) { entry.photos.first }

  before do
    attach_image_to_photo(photo)
    photo.update!(latitude: 40.7128, longitude: -74.0060)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('NATIVE_LAND_API_KEY').and_return('test_api_key')
  end

  describe '#perform' do
    it 'returns early when API key is missing' do
      allow(ENV).to receive(:[]).with('NATIVE_LAND_API_KEY').and_return(nil)
      expect(HTTParty).not_to receive(:get)
      described_class.new.perform(photo.id)
    end

    it 'returns early when photo has no location' do
      photo.update!(latitude: nil, longitude: nil)
      expect(HTTParty).not_to receive(:get)
      described_class.new.perform(photo.id)
    end

    it 'fetches territories and associates with photo' do
      response_body = [
        {
          'type' => 'Feature',
          'properties' => {
            'Slug' => 'lenape',
            'Name' => 'Lenape',
            'description' => 'https://native-land.ca/maps/territories/lenape/'
          }
        }
      ].to_json

      stub_request(:get, /native-land.ca/)
        .to_return(status: 200, body: response_body)

      described_class.new.perform(photo.id)
      photo.reload

      expect(photo.territories.count).to eq(1)
      expect(photo.territories.first.name).to eq('Lenape')
    end

    it 'creates new territories if not found' do
      response_body = [
        {
          'type' => 'Feature',
          'properties' => {
            'Slug' => 'new-territory',
            'Name' => 'New Territory',
            'description' => 'https://example.com'
          }
        }
      ].to_json

      stub_request(:get, /native-land.ca/)
        .to_return(status: 200, body: response_body)

      expect {
        described_class.new.perform(photo.id)
      }.to change(Territory, :count).by(1)
    end

    it 'enqueues CaptionValidityWorker after updating territories' do
      response_body = [
        {
          'type' => 'Feature',
          'properties' => {
            'Slug' => 'lenape',
            'Name' => 'Lenape',
            'description' => 'https://native-land.ca'
          }
        }
      ].to_json

      stub_request(:get, /native-land.ca/)
        .to_return(status: 200, body: response_body)

      # Clear any existing jobs from other tests
      CaptionValidityWorker.jobs.clear

      described_class.new.perform(photo.id)

      expect(CaptionValidityWorker.jobs.size).to eq(1)
    end

    it 'raises error when API request fails' do
      stub_request(:get, /native-land.ca/)
        .to_return(status: 500, body: 'Server Error')

      expect {
        described_class.new.perform(photo.id)
      }.to raise_error(/Native Lands API request failed/)
    end
  end
end
