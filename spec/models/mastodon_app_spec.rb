require 'rails_helper'

RSpec.describe MastodonApp, type: :model do
  describe 'validations' do
    subject { build(:mastodon_app) }

    it { should validate_presence_of(:instance_url) }
    it { should validate_presence_of(:client_id) }
    it { should validate_presence_of(:client_secret) }

    it 'validates uniqueness of instance_url' do
      create(:mastodon_app, instance_url: 'https://mastodon.social')
      duplicate = build(:mastodon_app, instance_url: 'https://mastodon.social')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:instance_url]).to include('has already been taken')
    end
  end

  describe 'encryption' do
    it 'encrypts client_secret' do
      app = create(:mastodon_app, client_secret: 'my-secret-key')
      app.reload

      expect(app.client_secret).to eq('my-secret-key')

      raw_value = MastodonApp.connection.select_value(
        "SELECT client_secret FROM mastodon_apps WHERE id = #{app.id}"
      )
      expect(raw_value).not_to eq('my-secret-key')
    end
  end

  describe '.normalize_url' do
    it 'adds https:// if missing' do
      expect(MastodonApp.normalize_url('mastodon.social')).to eq('https://mastodon.social')
    end

    it 'converts http to https' do
      expect(MastodonApp.normalize_url('http://mastodon.social')).to eq('https://mastodon.social')
    end

    it 'removes trailing slash' do
      expect(MastodonApp.normalize_url('https://mastodon.social/')).to eq('https://mastodon.social')
    end

    it 'downcases the URL' do
      expect(MastodonApp.normalize_url('HTTPS://Mastodon.Social')).to eq('https://mastodon.social')
    end

    it 'strips whitespace' do
      expect(MastodonApp.normalize_url('  mastodon.social  ')).to eq('https://mastodon.social')
    end
  end

  describe 'instance URL normalization' do
    it 'normalizes instance_url on save' do
      app = create(:mastodon_app, instance_url: 'mastodon.social')
      expect(app.instance_url).to eq('https://mastodon.social')
    end
  end

  describe '.for_instance' do
    context 'when app already exists' do
      let!(:existing_app) { create(:mastodon_app, instance_url: 'https://mastodon.social') }

      it 'returns the existing app' do
        result = MastodonApp.for_instance('mastodon.social')
        expect(result).to eq(existing_app)
      end

      it 'handles different URL formats' do
        expect(MastodonApp.for_instance('https://mastodon.social/')).to eq(existing_app)
        expect(MastodonApp.for_instance('http://mastodon.social')).to eq(existing_app)
        expect(MastodonApp.for_instance('MASTODON.SOCIAL')).to eq(existing_app)
      end
    end

    context 'when app does not exist' do
      before do
        stub_request(:post, "https://mastodon.social/api/v1/apps")
          .to_return(
            status: 200,
            body: {
              client_id: 'new_client_id',
              client_secret: 'new_client_secret'
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'registers a new app' do
        expect {
          MastodonApp.for_instance('mastodon.social')
        }.to change(MastodonApp, :count).by(1)
      end

      it 'returns the new app' do
        app = MastodonApp.for_instance('mastodon.social')
        expect(app.instance_url).to eq('https://mastodon.social')
        expect(app.client_id).to eq('new_client_id')
        expect(app.client_secret).to eq('new_client_secret')
      end
    end

    context 'when registration fails' do
      before do
        stub_request(:post, "https://mastodon.social/api/v1/apps")
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'raises an error' do
        expect {
          MastodonApp.for_instance('mastodon.social')
        }.to raise_error(/Failed to register app/)
      end
    end
  end

  describe '.redirect_uri' do
    it 'returns the callback URL' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('DOMAIN').and_return('example.com')

      uri = MastodonApp.redirect_uri
      expect(uri).to include('example.com')
      expect(uri).to include('mastodon/callback')
    end
  end

  describe 'factory' do
    it 'creates a valid mastodon app' do
      app = create(:mastodon_app)
      expect(app).to be_valid
    end
  end
end
