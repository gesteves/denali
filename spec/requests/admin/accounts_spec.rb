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
      expect(response.body).to include("Instagram")
      expect(response.body).to include("Mastodon")
      expect(response.body).to include("Threads")
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
        allow(ENV).to receive(:[]).with('INSTAGRAM_APP_ID').and_return('test_app_id')
        allow(ENV).to receive(:[]).with('INSTAGRAM_APP_SECRET').and_return('test_app_secret')
        allow(ENV).to receive(:[]).with('THREADS_APP_ID').and_return('test_app_id')
        allow(ENV).to receive(:[]).with('THREADS_APP_SECRET').and_return('test_app_secret')
      end

      it "displays the add account buttons" do
        get admin_accounts_path
        expect(response.body).to include("Connect with Bluesky")
        expect(response.body).to include("Connect with Flickr")
        expect(response.body).to include("Connect with Instagram")
        expect(response.body).to include("Connect Mastodon Account")
        expect(response.body).to include("Connect with Threads")
      end
    end

    context "when user has a connected Instagram account" do
      let!(:instagram_account) { create(:social_account, :instagram, user: user, handle: 'myinstauser') }

      it "displays the connected account" do
        get admin_accounts_path
        expect(response.body).to include("@myinstauser")
      end

      it "displays the disconnect button for Instagram" do
        get admin_accounts_path
        expect(response.body).to include("Disconnect")
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

    context "when user has a connected Threads account" do
      let!(:threads_account) { create(:social_account, :threads, user: user, handle: 'mythreadsuser') }

      it "displays the connected account" do
        get admin_accounts_path
        expect(response.body).to include("@mythreadsuser")
      end

      it "displays the disconnect button for Threads" do
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
        expect(flash[:danger]).to include("check your handle and app password")
      end

      it "shows friendly error with form visible (turbo_stream)" do
        post bluesky_admin_accounts_path, params: bluesky_params, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
        expect(response.body).to include('notification is-danger')
        expect(response.body).to include('check your handle and app password')
        expect(response.body).to include('Save')
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
        expect(flash[:danger]).to include("not configured")
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
        expect(flash[:success]).to include("connected successfully")
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
        expect(flash[:danger]).to include("Invalid OAuth token")
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
        expect(flash[:danger]).to include("enter your Mastodon instance URL")
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
        expect(flash[:danger]).to include("Could not reach")
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
        expect(flash[:success]).to include("connected successfully")
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
        expect(flash[:danger]).to include("Invalid OAuth state")
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
        expect(flash[:danger]).to include("Authorization was denied")
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

  describe "POST /admin/accounts/instagram (initiate_instagram)" do
    context "with Instagram credentials configured" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('INSTAGRAM_APP_ID').and_return('test_app_id')
        allow(ENV).to receive(:[]).with('INSTAGRAM_APP_SECRET').and_return('test_app_secret')
      end

      it "redirects to Instagram authorization page" do
        post instagram_admin_accounts_path
        expect(response).to redirect_to(/instagram\.com\/oauth\/authorize/)
      end

      it "includes required scopes in authorization URL" do
        post instagram_admin_accounts_path
        expect(response.location).to include('instagram_business_basic')
        expect(response.location).to include('instagram_business_content_publish')
      end

      it "stores OAuth state in session" do
        post instagram_admin_accounts_path
        expect(session[:instagram_oauth_state]).to be_present
      end
    end

    context "without Instagram credentials configured" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('INSTAGRAM_APP_ID').and_return(nil)
        allow(ENV).to receive(:[]).with('INSTAGRAM_APP_SECRET').and_return(nil)
      end

      it "redirects with error message" do
        post instagram_admin_accounts_path
        expect(response).to redirect_to(admin_accounts_path)
        expect(flash[:danger]).to include("not configured")
      end
    end
  end

  describe "GET /admin/accounts/instagram/callback (instagram_callback)" do
    let(:oauth_state) { SecureRandom.hex(32) }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('INSTAGRAM_APP_ID').and_return('test_app_id')
      allow(ENV).to receive(:[]).with('INSTAGRAM_APP_SECRET').and_return('test_app_secret')
      allow(ENV).to receive(:[]).with('DOMAIN_ADMIN').and_return(nil)
    end

    context "with valid callback" do
      before do
        # Initiate OAuth to set up session
        post instagram_admin_accounts_path

        stub_request(:post, "https://api.instagram.com/oauth/access_token")
          .to_return(
            status: 200,
            body: { access_token: 'short_lived_token', user_id: '12345' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        stub_request(:get, "https://graph.instagram.com/access_token")
          .with(query: hash_including(grant_type: 'ig_exchange_token'))
          .to_return(
            status: 200,
            body: { access_token: 'long_lived_token', expires_in: 5184000 }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        stub_request(:get, "https://graph.instagram.com/me")
          .with(query: hash_including(access_token: 'long_lived_token'))
          .to_return(
            status: 200,
            body: { user_id: '12345', username: 'testinstauser' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it "creates an Instagram social account" do
        state = session[:instagram_oauth_state]

        expect {
          get instagram_callback_admin_accounts_path, params: { code: 'auth_code', state: state }
        }.to change(SocialAccount, :count).by(1)

        account = SocialAccount.last
        expect(account.provider).to eq('instagram')
        expect(account.handle).to eq('testinstauser')
        expect(account.uid).to eq('12345')
      end

      it "redirects to accounts page with success message" do
        state = session[:instagram_oauth_state]
        get instagram_callback_admin_accounts_path, params: { code: 'auth_code', state: state }

        expect(response).to redirect_to(admin_accounts_path)
        expect(flash[:success]).to include("connected successfully")
      end

      it "clears OAuth session data" do
        state = session[:instagram_oauth_state]
        get instagram_callback_admin_accounts_path, params: { code: 'auth_code', state: state }

        expect(session[:instagram_oauth_state]).to be_nil
      end
    end

    context "with invalid state" do
      it "redirects with error" do
        get instagram_callback_admin_accounts_path, params: { code: 'auth_code', state: 'invalid_state' }

        expect(response).to redirect_to(admin_accounts_path)
        expect(flash[:danger]).to include("Invalid OAuth state")
      end
    end

    context "when authorization is denied" do
      before do
        post instagram_admin_accounts_path
      end

      it "redirects with error message" do
        state = session[:instagram_oauth_state]
        get instagram_callback_admin_accounts_path, params: { error: 'access_denied', error_description: 'User denied access', state: state }

        expect(response).to redirect_to(admin_accounts_path)
        expect(flash[:danger]).to include("Authorization was denied")
      end
    end

    context "when token exchange fails" do
      before do
        post instagram_admin_accounts_path

        stub_request(:post, "https://api.instagram.com/oauth/access_token")
          .to_return(status: 400, body: { error: 'invalid_code' }.to_json)
      end

      it "redirects with error message" do
        state = session[:instagram_oauth_state]
        get instagram_callback_admin_accounts_path, params: { code: 'invalid_code', state: state }

        expect(response).to redirect_to(admin_accounts_path)
        expect(flash[:danger]).to include("Failed to get access token")
      end
    end
  end

  describe "DELETE /admin/accounts/instagram (destroy_instagram)" do
    let!(:instagram_account) { create(:social_account, :instagram, user: user) }

    it "deletes the Instagram account" do
      expect {
        delete instagram_admin_accounts_path
      }.to change(SocialAccount, :count).by(-1)
    end

    it "redirects to accounts page (HTML)" do
      delete instagram_admin_accounts_path
      expect(response).to redirect_to(admin_accounts_path)
    end

    it "returns turbo_stream response" do
      delete instagram_admin_accounts_path, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end

    context "when user has no Instagram account" do
      before { instagram_account.destroy }

      it "handles gracefully" do
        expect {
          delete instagram_admin_accounts_path
        }.not_to raise_error
        expect(response).to redirect_to(admin_accounts_path)
      end
    end
  end

  describe "POST /admin/accounts/threads (initiate_threads)" do
    context "with Threads credentials configured" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('THREADS_APP_ID').and_return('test_app_id')
        allow(ENV).to receive(:[]).with('THREADS_APP_SECRET').and_return('test_app_secret')
      end

      it "redirects to Threads authorization page" do
        post threads_admin_accounts_path
        expect(response).to redirect_to(/threads\.net\/oauth\/authorize/)
      end

      it "includes required scopes in authorization URL" do
        post threads_admin_accounts_path
        expect(response.location).to include('threads_basic')
        expect(response.location).to include('threads_content_publish')
        expect(response.location).to include('threads_location_tagging')
      end

      it "stores OAuth state in session" do
        post threads_admin_accounts_path
        expect(session[:threads_oauth_state]).to be_present
      end
    end

    context "without Threads credentials configured" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('THREADS_APP_ID').and_return(nil)
        allow(ENV).to receive(:[]).with('THREADS_APP_SECRET').and_return(nil)
      end

      it "redirects with error message" do
        post threads_admin_accounts_path
        expect(response).to redirect_to(admin_accounts_path)
        expect(flash[:danger]).to include("not configured")
      end
    end
  end

  describe "GET /admin/accounts/threads/callback (threads_callback)" do
    let(:oauth_state) { SecureRandom.hex(32) }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('THREADS_APP_ID').and_return('test_app_id')
      allow(ENV).to receive(:[]).with('THREADS_APP_SECRET').and_return('test_app_secret')
      allow(ENV).to receive(:[]).with('DOMAIN_ADMIN').and_return(nil)
    end

    context "with valid callback" do
      before do
        # Initiate OAuth to set up session
        post threads_admin_accounts_path

        stub_request(:post, "https://graph.threads.net/oauth/access_token")
          .to_return(
            status: 200,
            body: { access_token: 'short_lived_token', user_id: '12345' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        stub_request(:get, "https://graph.threads.net/access_token")
          .with(query: hash_including(grant_type: 'th_exchange_token'))
          .to_return(
            status: 200,
            body: { access_token: 'long_lived_token', expires_in: 5184000 }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        stub_request(:get, "https://graph.threads.net/v1.0/me")
          .with(query: hash_including(access_token: 'long_lived_token'))
          .to_return(
            status: 200,
            body: { id: '12345', username: 'testthreadsuser' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it "creates a Threads social account" do
        state = session[:threads_oauth_state]

        expect {
          get threads_callback_admin_accounts_path, params: { code: 'auth_code', state: state }
        }.to change(SocialAccount, :count).by(1)

        account = SocialAccount.last
        expect(account.provider).to eq('threads')
        expect(account.handle).to eq('testthreadsuser')
        expect(account.uid).to eq('12345')
      end

      it "redirects to accounts page with success message" do
        state = session[:threads_oauth_state]
        get threads_callback_admin_accounts_path, params: { code: 'auth_code', state: state }

        expect(response).to redirect_to(admin_accounts_path)
        expect(flash[:success]).to include("connected successfully")
      end

      it "clears OAuth session data" do
        state = session[:threads_oauth_state]
        get threads_callback_admin_accounts_path, params: { code: 'auth_code', state: state }

        expect(session[:threads_oauth_state]).to be_nil
      end
    end

    context "with invalid state" do
      it "redirects with error" do
        get threads_callback_admin_accounts_path, params: { code: 'auth_code', state: 'invalid_state' }

        expect(response).to redirect_to(admin_accounts_path)
        expect(flash[:danger]).to include("Invalid OAuth state")
      end
    end

    context "when authorization is denied" do
      before do
        post threads_admin_accounts_path
      end

      it "redirects with error message" do
        state = session[:threads_oauth_state]
        get threads_callback_admin_accounts_path, params: { error: 'access_denied', error_description: 'User denied access', state: state }

        expect(response).to redirect_to(admin_accounts_path)
        expect(flash[:danger]).to include("Authorization was denied")
      end
    end

    context "when token exchange fails" do
      before do
        post threads_admin_accounts_path

        stub_request(:post, "https://graph.threads.net/oauth/access_token")
          .to_return(status: 400, body: { error: 'invalid_code' }.to_json)
      end

      it "redirects with error message" do
        state = session[:threads_oauth_state]
        get threads_callback_admin_accounts_path, params: { code: 'invalid_code', state: state }

        expect(response).to redirect_to(admin_accounts_path)
        expect(flash[:danger]).to include("Failed to get access token")
      end
    end
  end

  describe "DELETE /admin/accounts/threads (destroy_threads)" do
    let!(:threads_account) { create(:social_account, :threads, user: user) }

    it "deletes the Threads account" do
      expect {
        delete threads_admin_accounts_path
      }.to change(SocialAccount, :count).by(-1)
    end

    it "redirects to accounts page (HTML)" do
      delete threads_admin_accounts_path
      expect(response).to redirect_to(admin_accounts_path)
    end

    it "returns turbo_stream response" do
      delete threads_admin_accounts_path, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end

    context "when user has no Threads account" do
      before { threads_account.destroy }

      it "handles gracefully" do
        expect {
          delete threads_admin_accounts_path
        }.not_to raise_error
        expect(response).to redirect_to(admin_accounts_path)
      end
    end
  end

  describe "Instagram webhooks (no auth required)" do
    # These tests don't use the sign_in_as from the parent before block
    # because webhooks don't require authentication
    let(:app_secret) { 'test_app_secret' }
    let(:instagram_user_id) { '12345' }
    let!(:instagram_account) { create(:social_account, :instagram, uid: instagram_user_id) }

    def create_signed_request(user_id, secret)
      payload_data = { 'algorithm' => 'HMAC-SHA256', 'user_id' => user_id, 'issued_at' => Time.now.to_i }
      payload = Base64.urlsafe_encode64(payload_data.to_json, padding: false)
      signature = OpenSSL::HMAC.digest('SHA256', secret, payload)
      encoded_sig = Base64.urlsafe_encode64(signature, padding: false)
      "#{encoded_sig}.#{payload}"
    end

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('INSTAGRAM_APP_SECRET').and_return(app_secret)
    end

    describe "POST /admin/accounts/instagram/deauthorize" do
      it "deletes the Instagram account when signed request is valid" do
        signed_request = create_signed_request(instagram_user_id, app_secret)

        expect {
          post instagram_deauthorize_admin_accounts_path, params: { signed_request: signed_request }
        }.to change(SocialAccount.instagram, :count).by(-1)

        expect(response).to have_http_status(:ok)
      end

      it "returns ok even with invalid signed request" do
        post instagram_deauthorize_admin_accounts_path, params: { signed_request: 'invalid' }
        expect(response).to have_http_status(:ok)
      end
    end

    describe "POST /admin/accounts/instagram/delete" do
      it "deletes the Instagram account and returns confirmation" do
        signed_request = create_signed_request(instagram_user_id, app_secret)

        expect {
          post instagram_delete_admin_accounts_path, params: { signed_request: signed_request }
        }.to change(SocialAccount.instagram, :count).by(-1)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['url']).to be_present
        expect(json['confirmation_code']).to be_present
      end

      it "returns bad request with invalid signed request" do
        post instagram_delete_admin_accounts_path, params: { signed_request: 'invalid' }
        expect(response).to have_http_status(:bad_request)
      end
    end

    describe "GET /admin/accounts/instagram/deletion_status" do
      it "displays confirmation message" do
        get instagram_deletion_status_admin_accounts_path, params: { code: 'abc123' }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('abc123')
      end
    end
  end

  describe "Threads webhooks (no auth required)" do
    # These tests don't use the sign_in_as from the parent before block
    # because webhooks don't require authentication
    let(:app_secret) { 'test_app_secret' }
    let(:threads_user_id) { '67890' }
    let!(:threads_account) { create(:social_account, :threads, uid: threads_user_id) }

    def create_signed_request(user_id, secret)
      payload_data = { 'algorithm' => 'HMAC-SHA256', 'user_id' => user_id, 'issued_at' => Time.now.to_i }
      payload = Base64.urlsafe_encode64(payload_data.to_json, padding: false)
      signature = OpenSSL::HMAC.digest('SHA256', secret, payload)
      encoded_sig = Base64.urlsafe_encode64(signature, padding: false)
      "#{encoded_sig}.#{payload}"
    end

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('THREADS_APP_SECRET').and_return(app_secret)
    end

    describe "POST /admin/accounts/threads/deauthorize" do
      it "deletes the Threads account when signed request is valid" do
        signed_request = create_signed_request(threads_user_id, app_secret)

        expect {
          post threads_deauthorize_admin_accounts_path, params: { signed_request: signed_request }
        }.to change(SocialAccount.threads, :count).by(-1)

        expect(response).to have_http_status(:ok)
      end

      it "returns ok even with invalid signed request" do
        post threads_deauthorize_admin_accounts_path, params: { signed_request: 'invalid' }
        expect(response).to have_http_status(:ok)
      end
    end

    describe "POST /admin/accounts/threads/delete" do
      it "deletes the Threads account and returns confirmation" do
        signed_request = create_signed_request(threads_user_id, app_secret)

        expect {
          post threads_delete_admin_accounts_path, params: { signed_request: signed_request }
        }.to change(SocialAccount.threads, :count).by(-1)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['url']).to be_present
        expect(json['confirmation_code']).to be_present
      end

      it "returns bad request with invalid signed request" do
        post threads_delete_admin_accounts_path, params: { signed_request: 'invalid' }
        expect(response).to have_http_status(:bad_request)
      end
    end

    describe "GET /admin/accounts/threads/deletion_status" do
      it "displays confirmation message" do
        get threads_deletion_status_admin_accounts_path, params: { code: 'xyz789' }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('xyz789')
      end
    end
  end
end
