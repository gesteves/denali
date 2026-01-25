require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should have_many(:entries) }
  end

  describe 'factory' do
    it 'creates a valid user' do
      user = create(:user)
      expect(user).to be_invalid
    end
  end

  describe '.from_omniauth' do
    let(:auth) do
      OmniAuth::AuthHash.new(
        provider: 'google_oauth2',
        uid: '123456',
        info: {
          name: 'Test User',
          first_name: 'Test',
          last_name: 'User',
          email: 'test@example.com',
          image: 'https://example.com/avatar.jpg'
        },
        credentials: {
          token: 'test_token',
          expires_at: 1.day.from_now.to_i
        }
      )
    end

    it 'creates a new user from omniauth data' do
      user = User.from_omniauth(auth)
      expect(user).to be_persisted
      expect(user.provider).to eq('google_oauth2')
      expect(user.uid).to eq('123456')
      expect(user.name).to eq('Test User')
      expect(user.email).to eq('test@example.com')
    end

    it 'finds existing user by provider and uid' do
      existing_user = create(:user, provider: 'google_oauth2', uid: '123456')
      user = User.from_omniauth(auth)
      expect(user.id).to eq(existing_user.id)
    end

    it 'updates user data on subsequent logins' do
      existing_user = create(:user, provider: 'google_oauth2', uid: '123456', name: 'Old Name')
      user = User.from_omniauth(auth)
      expect(user.name).to eq('Test User')
    end
  end
end
