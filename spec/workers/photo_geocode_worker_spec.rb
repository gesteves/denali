require 'rails_helper'

RSpec.describe PhotoGeocodeWorker, type: :worker do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
  let(:photo) { entry.photos.first }

  before do
    attach_image_to_photo(photo)
    photo.update!(latitude: 40.7128, longitude: -74.0060)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('GOOGLE_API_KEY').and_return('test_api_key')
  end

  describe '#perform' do
    it 'returns early when API key is missing' do
      allow(ENV).to receive(:[]).with('GOOGLE_API_KEY').and_return(nil)
      expect(HTTParty).not_to receive(:get)
      described_class.new.perform(photo.id)
    end

    it 'returns early when photo has no location' do
      photo.update!(latitude: nil, longitude: nil)
      expect(HTTParty).not_to receive(:get)
      described_class.new.perform(photo.id)
    end

    it 'geocodes photo location from coordinates' do
      response_body = {
        'status' => 'OK',
        'results' => [{
          'address_components' => [
            { 'types' => ['country'], 'long_name' => 'United States' },
            { 'types' => ['locality'], 'long_name' => 'New York' },
            { 'types' => ['administrative_area_level_1'], 'long_name' => 'New York' },
            { 'types' => ['postal_code'], 'long_name' => '10001' }
          ]
        }]
      }.to_json

      stub_request(:get, /maps.googleapis.com/)
        .to_return(status: 200, body: response_body)

      described_class.new.perform(photo.id)
      photo.reload

      expect(photo.country).to eq('United States')
      expect(photo.locality).to eq('New York')
      expect(photo.administrative_area).to eq('New York')
    end

    it 'raises error when geocode request fails' do
      response_body = { 'status' => 'ZERO_RESULTS' }.to_json

      stub_request(:get, /maps.googleapis.com/)
        .to_return(status: 200, body: response_body)

      expect {
        described_class.new.perform(photo.id)
      }.to raise_error(/Geocode request failed/)
    end
  end
end
