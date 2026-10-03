require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should have_many(:entries) }
    it { should have_many(:social_accounts).dependent(:destroy) }
  end

  describe 'factory' do
    it 'creates a valid user' do
      user = create(:user)
      expect(user).to be_valid
    end
  end

  describe '#bluesky_account' do
    let(:user) { create(:user) }

    context 'when user has a bluesky account' do
      let!(:bluesky_account) { create(:social_account, user: user, provider: 'bluesky') }

      it 'returns the bluesky account' do
        expect(user.bluesky_account).to eq(bluesky_account)
      end
    end

    context 'when user has no bluesky account' do
      it 'returns nil' do
        expect(user.bluesky_account).to be_nil
      end
    end
  end

  describe '#flickr_account' do
    let(:user) { create(:user) }

    context 'when user has a flickr account' do
      let!(:flickr_account) { create(:social_account, :flickr, user: user) }

      it 'returns the flickr account' do
        expect(user.flickr_account).to eq(flickr_account)
      end
    end

    context 'when user has no flickr account' do
      it 'returns nil' do
        expect(user.flickr_account).to be_nil
      end
    end
  end
end
