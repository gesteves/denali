require 'rails_helper'

RSpec.describe OpenGraphJob, type: :worker do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, :with_photo, blog: blog, user: user) }

  before do
    entry.photos.each { |p| attach_image_to_photo(p) }
    allow(Rails.env).to receive(:production?).and_return(true)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('FACEBOOK_APP_ID').and_return('app_id')
    allow(ENV).to receive(:[]).with('FACEBOOK_APP_SECRET').and_return('app_secret')
  end

  describe '#perform' do
    it 'returns early in non-production environment' do
      allow(Rails.env).to receive(:production?).and_return(false)
      expect(HTTParty).not_to receive(:post)
      described_class.new.perform(entry.id)
    end

    it 'returns early when credentials are missing' do
      allow(ENV).to receive(:[]).with('FACEBOOK_APP_ID').and_return(nil)
      expect(HTTParty).not_to receive(:post)
      described_class.new.perform(entry.id)
    end

    it 'scrapes OpenGraph for entry URL' do
      stub_request(:post, /graph\.facebook\.com/)
        .to_return(status: 200, body: { 'id' => entry.permalink_url }.to_json)

      expect { described_class.new.perform(entry.id) }.not_to raise_error
    end

    it 'raises error when Facebook returns error' do
      stub_request(:post, /graph\.facebook\.com/)
        .to_return(status: 200, body: { 'error' => { 'code' => 100, 'message' => 'Invalid URL' } }.to_json)

      expect {
        described_class.new.perform(entry.id)
      }.to raise_error(/100 Invalid URL/)
    end
  end
end
