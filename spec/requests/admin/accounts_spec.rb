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
      it "displays the add account button" do
        get admin_accounts_path
        expect(response.body).to include("Add Bluesky Account")
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
end
