require 'rails_helper'

RSpec.describe FlickrGroupJob, type: :worker do
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
      described_class.new.perform('123456', 'https://flickr.com/groups/nature', user.id)
    end

    it 'returns early when user has no Flickr account' do
      flickr_account.destroy
      expect(FlickRaw::Flickr).not_to receive(:new)
      described_class.new.perform('123456', 'https://flickr.com/groups/nature', user.id)
    end

    it 'returns early when user_id is not provided' do
      expect(FlickRaw::Flickr).not_to receive(:new)
      described_class.new.perform('123456', 'https://flickr.com/groups/nature')
    end

    it 'adds photo to group using path alias' do
      flickr = double('FlickRaw::Flickr')
      groups = double('groups')
      pools = double('pools')
      allow(FlickRaw::Flickr).to receive(:new).and_return(flickr)
      allow(flickr).to receive(:access_token=)
      allow(flickr).to receive(:access_secret=)
      allow(flickr).to receive(:groups).and_return(groups)
      allow(groups).to receive(:getInfo).with(group_path_alias: 'nature').and_return({ 'nsid' => '12345@N00' })
      allow(groups).to receive(:pools).and_return(pools)

      expect(pools).to receive(:add).with(photo_id: '123456', group_id: '12345@N00')

      described_class.new.perform('123456', 'https://flickr.com/groups/nature', user.id)
    end

    it 'adds photo to group using NSID directly' do
      flickr = double('FlickRaw::Flickr')
      groups = double('groups')
      pools = double('pools')
      allow(FlickRaw::Flickr).to receive(:new).and_return(flickr)
      allow(flickr).to receive(:access_token=)
      allow(flickr).to receive(:access_secret=)
      allow(flickr).to receive(:groups).and_return(groups)
      allow(groups).to receive(:getInfo).with(group_id: '12345@N00').and_return({ 'nsid' => '12345@N00' })
      allow(groups).to receive(:pools).and_return(pools)

      expect(pools).to receive(:add).with(photo_id: '123456', group_id: '12345@N00')

      described_class.new.perform('123456', 'https://flickr.com/groups/12345@N00', user.id)
    end

    it 'handles FlickRaw errors gracefully' do
      flickr = double('FlickRaw::Flickr')
      groups = double('groups')
      allow(FlickRaw::Flickr).to receive(:new).and_return(flickr)
      allow(flickr).to receive(:access_token=)
      allow(flickr).to receive(:access_secret=)
      allow(flickr).to receive(:groups).and_return(groups)
      allow(groups).to receive(:getInfo).and_raise(FlickRaw::FailedResponse.new(1, 'Error', 'groups.getInfo'))

      expect { described_class.new.perform('123456', 'https://flickr.com/groups/nature', user.id) }.not_to raise_error
    end
  end
end
