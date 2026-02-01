require 'rails_helper'

RSpec.describe "Admin::Accounts", type: :request do
  let(:user) { create(:user) }
  let!(:blog) { Blog.first || create(:blog) }

  before do
    sign_in_as(user)
  end

  describe "GET /admin/accounts (index)" do
    it "renders successfully" do
      get admin_accounts_path
      expect(response).to have_http_status(:success)
    end

    it "displays connected accounts page" do
      get admin_accounts_path
      expect(response.body).to include("Connected Accounts")
      expect(response.body).to include("Bluesky")
      expect(response.body).to include("Flickr")
      expect(response.body).to include("Mastodon")
    end

    context "when user has a connected Bluesky account" do
      let!(:bluesky_account) { create(:social_account, user: user, provider: 'bluesky', handle: 'myhandle.bsky.social') }

      it "displays the connected account" do
        get admin_accounts_path
        expect(response.body).to include("@myhandle.bsky.social")
      end

      it "displays the disconnect button" do
        get admin_accounts_path
        expect(response.body).to include("Disconnect")
      end
    end

    context "when user has no connected accounts" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('FLICKR_CONSUMER_KEY').and_return('test_key')
        allow(ENV).to receive(:[]).with('FLICKR_CONSUMER_SECRET').and_return('test_secret')
      end

      it "displays the add account buttons" do
        get admin_accounts_path
        expect(response.body).to include("Add Bluesky Account")
        expect(response.body).to include("Connect with Flickr")
        expect(response.body).to include("Connect Mastodon Account")
      end
    end

    context "when user has a connected Flickr account" do
      let!(:flickr_account) { create(:social_account, :flickr, user: user, handle: 'myflickruser') }

      it "displays the connected account" do
        get admin_accounts_path
        expect(response.body).to include("myflickruser")
      end

      it "displays the disconnect button for Flickr" do
        get admin_accounts_path
        expect(response.body).to include("Disconnect")
      end
    end

    context "when user has a connected Mastodon account" do
      let!(:mastodon_account) { create(:social_account, :mastodon, user: user, handle: 'myhandle@mastodon.social') }

      it "displays the connected account" do
        get admin_accounts_path
        expect(response.body).to include("@myhandle@mastodon.social")
      end

      it "displays the disconnect button for Mastodon" do
        get admin_accounts_path
        expect(response.body).to include("Disconnect")
      end
    end
  end

  describe "POST /admin/accounts/bluesky (create_bluesky)" do
    let(:bluesky_params) do
      {
        social_account: {
          handle: 'testuser.bsky.social',
          access_token: 'xxxx-xxxx-xxxx-xxxx',
          server_url: 'https://bsky.social'
        }
      }
    end

    before do
      # Stub Bluesky API call to create session
      stub_request(:post, "https://bsky.social/xrpc/com.atproto.server.createSession")
        .to_return(
          status: 200,
          body: { did: 'did:plc:testuser123', accessJwt: 'test-jwt' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it "creates a new Bluesky account" do
      expect {
        post bluesky_admin_accounts_path, params: bluesky_params
      }.to change(SocialAccount, :count).by(1)
    end

    it "associates the account with the current user" do
      post bluesky_admin_accounts_path, params: bluesky_params
      account = SocialAccount.last
      expect(account.user).to eq(user)
      expect(account.provider).to eq('bluesky')
      expect(account.handle).to eq('testuser.bsky.social')
    end

    it "stores the DID from Bluesky" do
      post bluesky_admin_accounts_path, params: bluesky_params
      account = SocialAccount.last
      expect(account.uid).to eq('did:plc:testuser123')
    end

    it "redirects to accounts page on success (HTML)" do
      post bluesky_admin_accounts_path, params: bluesky_params
      expect(response).to redirect_to(admin_accounts_path)
    end

    it "returns turbo_stream on success" do
      post bluesky_admin_accounts_path, params: bluesky_params, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end

    context "when credentials are invalid" do
      before do
        stub_request(:post, "https://bsky.social/xrpc/com.atproto.server.createSession")
          .to_return(status: 401, body: { error: 'AuthenticationRequired' }.to_json)
      end

      it "does not create an account" do
        expect {
          post bluesky_admin_accounts_path, params: bluesky_params
        }.not_to change(SocialAccount, :count)
      end

      it "redirects with friendly error message (HTML)" do
        post bluesky_admin_accounts_path, params: bluesky_params
        expect(response).to redirect_to(admin_accounts_path)
        expect(flash[:alert]).to include("check your handle and app password")
      end

      it "shows friendly error with form visible (turbo_stream)" do
        post bluesky_admin_accounts_path, params: bluesky_params, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
        expect(response.body).to include('notification is-danger')
        expect(response.body).to include('check your handle and app password')
        expect(response.body).to include('Connect Account')
      end
    end

    context "when user already has a Bluesky account" do
      let!(:existing_account) { create(:social_account, user: user, provider: 'bluesky') }

      it "updates the existing account" do
        expect {
          post bluesky_admin_accounts_path, params: bluesky_params
        }.not_to change(SocialAccount, :count)

        existing_account.reload
        expect(existing_account.handle).to eq('testuser.bsky.social')
      end
    end
  end

  describe "DELETE /admin/accounts/bluesky (destroy_bluesky)" do
    let!(:bluesky_account) { create(:social_account, user: user, provider: 'bluesky') }

    it "deletes the Bluesky account" do
      expect {
        delete bluesky_admin_accounts_path
      }.to change(SocialAccount, :count).by(-1)
    end

    it "redirects to accounts page (HTML)" do
      delete bluesky_admin_accounts_path
      expect(response).to redirect_to(admin_accounts_path)
    end

    it "returns turbo_stream response" do
      delete bluesky_admin_accounts_path, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end

    context "when user has no Bluesky account" do
      before { bluesky_account.destroy }

      it "handles gracefully" do
        expect {
          delete bluesky_admin_accounts_path
        }.not_to raise_error
        expect(response).to redirect_to(admin_accounts_path)
      end
    end
  end

  describe "POST /admin/accounts/flickr (initiate_flickr)" do
    context "with Flickr credentials configured" do
      let(:flickr) { double('FlickRaw::Flickr') }

      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('FLICKR_CONSUMER_KEY').and_return('test_consumer_key')
        allow(ENV).to receive(:[]).with('FLICKR_CONSUMER_SECRET').and_return('test_consumer_secret')
        allow(FlickRaw::Flickr).to receive(:new).and_return(flickr)
        allow(flickr).to receive(:get_request_token).and_return({
          'oauth_token' => 'request_token',
          'oauth_token_secret' => 'request_secret'
        })
        allow(flickr).to receive(:get_authorize_url).and_return('https://www.flickr.com/services/oauth/authorize?oauth_token=request_token')
      end

      it "redirects to Flickr authorization page" do
        post flickr_admin_accounts_path
        expect(response).to redirect_to(/flickr\.com\/services\/oauth\/authorize/)
      end

      it "stores OAuth token in session" do
        post flickr_admin_accounts_path
        expect(session[:flickr_oauth_token]).to eq('request_token')
        expect(session[:flickr_oauth_token_secret]).to eq('request_secret')
      end
    end

    context "without Flickr credentials configured" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('FLICKR_CONSUMER_KEY').and_return(nil)
        allow(ENV).to receive(:[]).with('FLICKR_CONSUMER_SECRET').and_return(nil)
      end

      it "redirects with error message" do
        post flickr_admin_accounts_path
        expect(response).to redirect_to(admin_accounts_path)
        expect(flash[:alert]).to include("not configured")
      end
    end
  end

  describe "GET /admin/accounts/flickr/callback (flickr_callback)" do
    let(:flickr) { double('FlickRaw::Flickr') }
    let(:login) { double('login', id: '12345@N00', username: 'testflickruser') }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('FLICKR_CONSUMER_KEY').and_return('test_consumer_key')
      allow(ENV).to receive(:[]).with('FLICKR_CONSUMER_SECRET').and_return('test_consumer_secret')
    end

    context "with valid callback" do
      before do
        # Set up session
        allow(FlickRaw::Flickr).to receive(:new).and_return(flickr)
        allow(flickr).to receive(:get_request_token).and_return({
          'oauth_token' => 'request_token',
          'oauth_token_secret' => 'request_secret'
        })
        allow(flickr).to receive(:get_authorize_url).and_return('https://flickr.com/authorize')
        post flickr_admin_accounts_path

        # Set up callback mocks
        allow(flickr).to receive(:get_access_token).and_return({
          'oauth_token' => 'access_token',
          'oauth_token_secret' => 'access_secret'
        })
        allow(flickr).to receive(:access_token=)
        allow(flickr).to receive(:access_secret=)
        allow(flickr).to receive_message_chain(:test, :login).and_return(login)
      end

      it "creates a Flickr social account" do
        expect {
          get flickr_callback_admin_accounts_path, params: { oauth_token: 'request_token', oauth_verifier: 'verifier' }
        }.to change(SocialAccount, :count).by(1)

        account = SocialAccount.last
        expect(account.provider).to eq('flickr')
        expect(account.handle).to eq('testflickruser')
        expect(account.uid).to eq('12345@N00')
      end

      it "redirects to accounts page with success message" do
        get flickr_callback_admin_accounts_path, params: { oauth_token: 'request_token', oauth_verifier: 'verifier' }

        expect(response).to redirect_to(admin_accounts_path)
        expect(flash[:notice]).to include("connected successfully")
      end

      it "clears OAuth session data" do
        get flickr_callback_admin_accounts_path, params: { oauth_token: 'request_token', oauth_verifier: 'verifier' }

        expect(session[:flickr_oauth_token]).to be_nil
        expect(session[:flickr_oauth_token_secret]).to be_nil
      end
    end

    context "with invalid oauth_token" do
      before do
        # Initiate OAuth to set up session
        allow(FlickRaw::Flickr).to receive(:new).and_return(flickr)
        allow(flickr).to receive(:get_request_token).and_return({
          'oauth_token' => 'original_token',
          'oauth_token_secret' => 'secret'
        })
        allow(flickr).to receive(:get_authorize_url).and_return('https://flickr.com/authorize')
        post flickr_admin_accounts_path
      end

      it "redirects with error" do
        get flickr_callback_admin_accounts_path, params: { oauth_token: 'wrong_token', oauth_verifier: 'verifier' }

        expect(response).to redirect_to(admin_accounts_path)
        expect(flash[:alert]).to include("Invalid OAuth token")
      end
    end
  end

  describe "DELETE /admin/accounts/flickr (destroy_flickr)" do
    let!(:flickr_account) { create(:social_account, :flickr, user: user) }

    it "deletes the Flickr account" do
      expect {
        delete flickr_admin_accounts_path
      }.to change(SocialAccount, :count).by(-1)
    end

    it "redirects to accounts page (HTML)" do
      delete flickr_admin_accounts_path
      expect(response).to redirect_to(admin_accounts_path)
    end

    it "returns turbo_stream response" do
      delete flickr_admin_accounts_path, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end

    context "when user has no Flickr account" do
      before { flickr_account.destroy }

      it "handles gracefully" do
        expect {
          delete flickr_admin_accounts_path
        }.not_to raise_error
        expect(response).to redirect_to(admin_accounts_path)
      end
    end
  end

  describe "POST /admin/accounts/mastodon (initiate_mastodon)" do
    context "with valid instance URL" do
      let(:mastodon_app) { create(:mastodon_app, instance_url: 'https://mastodon.social') }

      before do
        allow(MastodonApp).to receive(:for_instance).with('mastodon.social').and_return(mastodon_app)
      end

      it "redirects to Mastodon authorization page" do
        post mastodon_admin_accounts_path, params: { instance_url: 'mastodon.social' }
        expect(response).to redirect_to(/mastodon\.social\/oauth\/authorize/)
      end

      it "stores OAuth state in session" do
        post mastodon_admin_accounts_path, params: { instance_url: 'mastodon.social' }
        expect(session[:mastodon_oauth_state]).to be_present
        expect(session[:mastodon_instance_url]).to eq('https://mastodon.social')
      end
    end

    context "with blank instance URL" do
      it "shows an error (HTML)" do
        post mastodon_admin_accounts_path, params: { instance_url: '' }
        expect(response).to redirect_to(admin_accounts_path)
        expect(flash[:alert]).to include("enter your Mastodon instance URL")
      end

      it "shows an error (turbo_stream)" do
        post mastodon_admin_accounts_path, params: { instance_url: '' }, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
        expect(response.body).to include('notification is-danger')
      end
    end

    context "when Mastodon instance is unreachable" do
      before do
        allow(MastodonApp).to receive(:for_instance).and_raise(Errno::ECONNREFUSED.new("Connection refused"))
      end

      it "shows a friendly error message" do
        post mastodon_admin_accounts_path, params: { instance_url: 'unreachable.social' }
        expect(response).to redirect_to(admin_accounts_path)
        expect(flash[:alert]).to include("Could not reach")
      end
    end
  end

  describe "GET /admin/accounts/mastodon/callback (mastodon_callback)" do
    let!(:mastodon_app) { create(:mastodon_app, instance_url: 'https://mastodon.social') }
    let(:oauth_state) { SecureRandom.hex(32) }

    context "with valid callback" do
      before do
        # Set up session via initiate action
        allow(MastodonApp).to receive(:for_instance).and_return(mastodon_app)
        post mastodon_admin_accounts_path, params: { instance_url: 'mastodon.social' }

        stub_request(:post, "https://mastodon.social/oauth/token")
          .to_return(
            status: 200,
            body: { access_token: 'test_access_token' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        stub_request(:get, "https://mastodon.social/api/v1/accounts/verify_credentials")
          .to_return(
            status: 200,
            body: { id: '12345', acct: 'testuser' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it "creates a Mastodon social account" do
        state = session[:mastodon_oauth_state]

        expect {
          get mastodon_callback_admin_accounts_path, params: { code: 'auth_code', state: state }
        }.to change(SocialAccount, :count).by(1)

        account = SocialAccount.last
        expect(account.provider).to eq('mastodon')
        expect(account.handle).to eq('testuser')
        expect(account.uid).to eq('12345')
        expect(account.server_url).to eq('https://mastodon.social')
      end

      it "redirects to accounts page with success message" do
        state = session[:mastodon_oauth_state]
        get mastodon_callback_admin_accounts_path, params: { code: 'auth_code', state: state }

        expect(response).to redirect_to(admin_accounts_path)
        expect(flash[:notice]).to include("connected successfully")
      end

      it "clears OAuth session data" do
        state = session[:mastodon_oauth_state]
        get mastodon_callback_admin_accounts_path, params: { code: 'auth_code', state: state }

        expect(session[:mastodon_oauth_state]).to be_nil
        expect(session[:mastodon_instance_url]).to be_nil
      end
    end

    context "with invalid state" do
      it "redirects with error" do
        get mastodon_callback_admin_accounts_path, params: { code: 'auth_code', state: 'invalid_state' }

        expect(response).to redirect_to(admin_accounts_path)
        expect(flash[:alert]).to include("Invalid OAuth state")
      end
    end

    context "when authorization is denied" do
      before do
        allow(MastodonApp).to receive(:for_instance).and_return(mastodon_app)
        post mastodon_admin_accounts_path, params: { instance_url: 'mastodon.social' }
      end

      it "redirects with error message" do
        state = session[:mastodon_oauth_state]
        get mastodon_callback_admin_accounts_path, params: { error: 'access_denied', error_description: 'User denied access', state: state }

        expect(response).to redirect_to(admin_accounts_path)
        expect(flash[:alert]).to include("Authorization was denied")
      end
    end
  end

  describe "DELETE /admin/accounts/mastodon (destroy_mastodon)" do
    let!(:mastodon_account) { create(:social_account, :mastodon, user: user) }

    it "deletes the Mastodon account" do
      expect {
        delete mastodon_admin_accounts_path
      }.to change(SocialAccount, :count).by(-1)
    end

    it "redirects to accounts page (HTML)" do
      delete mastodon_admin_accounts_path
      expect(response).to redirect_to(admin_accounts_path)
    end

    it "returns turbo_stream response" do
      delete mastodon_admin_accounts_path, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end

    context "when user has no Mastodon account" do
      before { mastodon_account.destroy }

      it "handles gracefully" do
        expect {
          delete mastodon_admin_accounts_path
        }.not_to raise_error
        expect(response).to redirect_to(admin_accounts_path)
      end
    end
  end
end
