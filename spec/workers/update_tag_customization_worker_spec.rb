require 'rails_helper'

RSpec.describe UpdateTagCustomizationWorker, type: :worker do
  let(:blog) { create(:blog) }
  let(:tag_customization) { create(:tag_customization, blog: blog, flickr_groups: "https://flickr.com/groups/nature\nhttps://flickr.com/groups/landscape") }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('FLICKR_CONSUMER_KEY').and_return('consumer_key')
    allow(ENV).to receive(:[]).with('FLICKR_CONSUMER_SECRET').and_return('consumer_secret')
    allow(ENV).to receive(:[]).with('FLICKR_ACCESS_TOKEN').and_return('access_token')
    allow(ENV).to receive(:[]).with('FLICKR_ACCESS_TOKEN_SECRET').and_return('access_secret')
  end

  describe '#perform' do
    it 'normalizes and deduplicates Flickr group URLs' do
      # Use double instead of instance_double since FlickRaw uses method_missing
      flickr = double('FlickRaw::Flickr')
      groups = double('groups')
      allow(FlickRaw::Flickr).to receive(:new).and_return(flickr)
      allow(flickr).to receive(:access_token=)
      allow(flickr).to receive(:access_secret=)
      allow(flickr).to receive(:groups).and_return(groups)

      # Return path aliases for lookups
      allow(groups).to receive(:getInfo).with(group_path_alias: 'nature').and_return({ 'path_alias' => 'nature', 'nsid' => '123@N00' })
      allow(groups).to receive(:getInfo).with(group_path_alias: 'landscape').and_return({ 'path_alias' => 'landscape', 'nsid' => '456@N00' })

      described_class.new.perform(tag_customization.id)
      tag_customization.reload

      expect(tag_customization.flickr_groups).to include('https://www.flickr.com/groups/nature/')
      expect(tag_customization.flickr_groups).to include('https://www.flickr.com/groups/landscape/')
    end

    it 'handles NSID format URLs' do
      tag_customization.update!(flickr_groups: 'https://flickr.com/groups/123456@N00')

      flickr = double('FlickRaw::Flickr')
      groups = double('groups')
      allow(FlickRaw::Flickr).to receive(:new).and_return(flickr)
      allow(flickr).to receive(:access_token=)
      allow(flickr).to receive(:access_secret=)
      allow(flickr).to receive(:groups).and_return(groups)
      allow(groups).to receive(:getInfo).with(group_id: '123456@N00').and_return({ 'path_alias' => 'test-group', 'nsid' => '123456@N00' })

      described_class.new.perform(tag_customization.id)
      tag_customization.reload

      expect(tag_customization.flickr_groups).to eq('https://www.flickr.com/groups/test-group/')
    end

    it 'keeps original slug when Flickr API fails' do
      tag_customization.update!(flickr_groups: 'https://flickr.com/groups/invalid-group')

      flickr = double('FlickRaw::Flickr')
      groups = double('groups')
      allow(FlickRaw::Flickr).to receive(:new).and_return(flickr)
      allow(flickr).to receive(:access_token=)
      allow(flickr).to receive(:access_secret=)
      allow(flickr).to receive(:groups).and_return(groups)
      # FlickRaw::FailedResponse takes 3 args: code, msg, and method
      allow(groups).to receive(:getInfo).and_raise(FlickRaw::FailedResponse.new(1, 'Not found', 'groups.getInfo'))

      described_class.new.perform(tag_customization.id)
      tag_customization.reload

      expect(tag_customization.flickr_groups).to eq('https://www.flickr.com/groups/invalid-group/')
    end
  end
end
