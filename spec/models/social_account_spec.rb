require 'rails_helper'

RSpec.describe SocialAccount, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    subject { build(:social_account) }

    it { should validate_presence_of(:provider) }
    it { should validate_presence_of(:handle) }
    it { should validate_presence_of(:access_token) }
    it { should validate_presence_of(:server_url) }
    it { should validate_inclusion_of(:provider).in_array(SocialAccount::PROVIDERS) }
    it { should validate_uniqueness_of(:provider).scoped_to(:user_id).with_message("account already connected") }
  end

  describe 'scopes' do
    describe '.bluesky' do
      let!(:bluesky_account) { create(:social_account, provider: 'bluesky') }

      it 'returns only bluesky accounts' do
        expect(SocialAccount.bluesky).to include(bluesky_account)
      end
    end
  end

  describe '#bluesky?' do
    it 'returns true for bluesky provider' do
      account = build(:social_account, provider: 'bluesky')
      expect(account.bluesky?).to be true
    end

    it 'returns false for other providers' do
      account = build(:social_account, provider: 'bluesky')
      account.provider = 'other'
      expect(account.bluesky?).to be false
    end
  end

  describe 'handle normalization' do
    it 'removes leading @ from handle' do
      account = create(:social_account, handle: '@user.bsky.social')
      expect(account.handle).to eq('user.bsky.social')
    end

    it 'leaves handle unchanged if no leading @' do
      account = create(:social_account, handle: 'user.bsky.social')
      expect(account.handle).to eq('user.bsky.social')
    end
  end

  describe 'encryption' do
    it 'encrypts access_token' do
      account = create(:social_account, access_token: 'my-secret-password')
      account.reload

      # The access_token should be decrypted when accessed
      expect(account.access_token).to eq('my-secret-password')

      # The raw value in the database should be encrypted (not equal to plain text)
      raw_value = SocialAccount.connection.select_value(
        "SELECT access_token FROM social_accounts WHERE id = #{account.id}"
      )
      expect(raw_value).not_to eq('my-secret-password')
    end
  end

  describe 'factory' do
    it 'creates a valid social account' do
      account = create(:social_account)
      expect(account).to be_valid
    end

    it 'creates a bluesky account by default' do
      account = create(:social_account)
      expect(account.provider).to eq('bluesky')
      expect(account.server_url).to eq('https://bsky.social')
    end
  end
end
