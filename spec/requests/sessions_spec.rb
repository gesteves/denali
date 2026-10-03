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

    it "displays flash messages" do
      get signin_path, params: {}, headers: {}
      # Set a flash and follow redirect to verify rendering
      delete signout_path
      follow_redirect!
      expect(response.body).to include("signed out")
    end
  end

  describe "GET /auth/google_oauth2/callback (create)" do
    before do
      OmniAuth.config.test_mode = true
    end

    after do
      OmniAuth.config.mock_auth[:google_oauth2] = nil
    end

    context "with an existing user" do
      before do
        OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
          provider: 'google_oauth2',
          uid: user.uid,
          info: {
            name: user.name,
            email: user.email,
            first_name: user.name.split.first,
            last_name: user.name.split.last,
            image: 'https://example.com/avatar.jpg'
          },
          credentials: {
            token: 'mock_token',
            refresh_token: 'mock_refresh_token',
            expires_at: Time.now.to_i + 3600
          }
        })
      end

      it "signs in the user and redirects" do
        get '/auth/google_oauth2/callback'
        expect(response).to redirect_to(admin_entries_path)
        expect(flash[:success]).to be_present
      end

      it "issues a new session on sign-in" do
        get admin_tags_path # writes original_url, so the session has an ID
        session_id_before = session.id.to_s
        expect(session_id_before).to be_present

        get '/auth/google_oauth2/callback'

        expect(session[:user_id]).to eq(user.id)
        expect(session.id.to_s).not_to eq(session_id_before)
      end

      it "still returns to the page that required sign-in" do
        get admin_tags_path
        get '/auth/google_oauth2/callback'
        expect(response).to redirect_to('http://www.example.com/admin/tags')
      end
    end

    context "with an unknown email" do
      before do
        OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
          provider: 'google_oauth2',
          uid: 'unknown_uid',
          info: {
            name: 'Unknown Person',
            email: 'unknown@example.com',
            first_name: 'Unknown',
            last_name: 'Person',
            image: 'https://example.com/avatar.jpg'
          },
          credentials: {
            token: 'mock_token',
            refresh_token: 'mock_refresh_token',
            expires_at: Time.now.to_i + 3600
          }
        })
      end

      it "rejects the sign-in and redirects to signin" do
        get '/auth/google_oauth2/callback'
        expect(response).to redirect_to(signin_path)
        expect(flash[:warning]).to include('not authorized')
      end

      it "does not create a new user" do
        expect {
          get '/auth/google_oauth2/callback'
        }.not_to change(User, :count)
      end
    end
  end

  describe "GET /auth/failure (failure)" do
    it "redirects to signin with error message" do
      get auth_failure_path, params: { message: 'access_denied' }
      expect(response).to redirect_to(signin_path)
      expect(flash[:warning]).to include('access_denied')
    end
  end

  describe "DELETE /signout (destroy)" do
    it "signs out the user" do
      sign_in_as(user)
      delete signout_path
      expect(response).to redirect_to(signin_path)
      expect(flash[:success]).to include("signed out")
    end

    # A GET would let any page sign the admin out with an <img> tag.
    it "isn't routable with GET" do
      sign_in_as(user)
      get '/signout'
      expect(response).not_to redirect_to(signin_path)
    end
  end
end
