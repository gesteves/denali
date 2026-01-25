require 'rails_helper'

RSpec.describe "Sessions", type: :request do
  let!(:blog) { Blog.first || create(:blog) }
  let(:user) { create(:user, uid: 'test_uid_123') }

  describe "GET /signin (new)" do
    it "renders successfully" do
      get signin_path
      expect(response).to have_http_status(:success)
    end

    it "displays sign in page title" do
      get signin_path
      expect(response.body).to include("Sign in")
    end
  end

  describe "GET /auth/google_oauth2/callback (create)" do
    before do
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
        provider: 'google_oauth2',
        uid: user.uid,
        info: {
          name: user.name,
          email: user.email,
          first_name: user.name.split.first
        },
        credentials: {
          token: 'mock_token',
          refresh_token: 'mock_refresh_token',
          expires_at: Time.now.to_i + 3600
        }
      })
    end

    after do
      OmniAuth.config.mock_auth[:google_oauth2] = nil
    end

    it "signs in the user and redirects" do
      get '/auth/google_oauth2/callback'
      expect(response).to redirect_to(admin_entries_path)
      expect(flash[:success]).to be_present
    end
  end

  describe "GET /auth/failure (failure)" do
    it "redirects to signin with error message" do
      get auth_failure_path, params: { message: 'access_denied' }
      expect(response).to redirect_to(signin_path)
      expect(flash[:warning]).to include('access_denied')
    end
  end

  describe "GET /signout (destroy)" do
    it "signs out the user" do
      sign_in_as(user)
      get signout_path
      expect(response).to redirect_to(signin_path)
      expect(flash[:success]).to include("signed out")
    end
  end
end
