require 'rails_helper'

RSpec.describe NationalParkWorker, type: :worker do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }
  let(:photo) { entry.photos.first }

  before do
    attach_image_to_photo(photo)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('NPS_API_KEY').and_return('test_api_key')
  end

  describe '#perform' do
    it 'returns early when API key is missing' do
      allow(ENV).to receive(:[]).with('NPS_API_KEY').and_return(nil)
      expect(HTTParty).not_to receive(:get)
      described_class.new.perform(photo.id, 'yose')
    end

    it 'returns early when park code is blank' do
      expect(HTTParty).not_to receive(:get)
      described_class.new.perform(photo.id, '')
    end

    it 'returns early for invalid park code format' do
      expect(HTTParty).not_to receive(:get)
      described_class.new.perform(photo.id, 'ab')  # Too short
      described_class.new.perform(photo.id, '1234')  # Contains numbers
    end

    it 'creates park and associates with photo' do
      response_body = {
        'data' => [{
          'parkCode' => 'yose',
          'fullName' => 'Yosemite National Park',
          'name' => 'Yosemite',
          'designation' => 'National Park',
          'url' => 'https://www.nps.gov/yose/'
        }]
      }.to_json

      stub_request(:get, /developer.nps.gov/)
        .to_return(status: 200, body: response_body)

      described_class.new.perform(photo.id, 'yose')
      photo.reload

      expect(photo.park).not_to be_nil
      expect(photo.park.full_name).to eq('Yosemite National Park')
      expect(photo.park.code).to eq('yose')
    end

    it 'reuses existing park if found' do
      existing_park = create(:park, code: 'yose', full_name: 'Yosemite National Park')

      response_body = {
        'data' => [{
          'parkCode' => 'yose',
          'fullName' => 'Yosemite National Park',
          'name' => 'Yosemite',
          'designation' => 'National Park',
          'url' => 'https://www.nps.gov/yose/'
        }]
      }.to_json

      stub_request(:get, /developer.nps.gov/)
        .to_return(status: 200, body: response_body)

      expect {
        described_class.new.perform(photo.id, 'yose')
      }.not_to change(Park, :count)

      photo.reload
      expect(photo.park).to eq(existing_park)
    end
  end
end
