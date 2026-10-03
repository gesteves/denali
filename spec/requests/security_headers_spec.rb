require 'rails_helper'

RSpec.describe "Security headers", type: :request do
  let!(:blog) { Blog.first || create(:blog) }
  let(:user) { create(:user) }

  # Public pages used to send no-referrer-when-downgrade, which leaked full
  # URLs (including /preview/<hash>) to every third party a page loads.
  it "uses Rails' default referrer policy on public pages" do
    entry = create(:entry, :published, :with_photo, blog: blog, user: user)
    entry.photos.each { |p| attach_image_to_photo(p) }

    get entries_path

    expect(response).to have_http_status(:success)
    expect(response.headers['Referrer-Policy']).to eq('strict-origin-when-cross-origin')
  end

  describe "admin" do
    before { sign_in_as(user) }

    it "keeps the referrer on the admin host" do
      get admin_entries_path
      expect(response.headers['Referrer-Policy']).to eq('same-origin')
    end

    it "sends a report-only content security policy" do
      get admin_entries_path

      policy = response.headers['Content-Security-Policy-Report-Only']
      expect(policy).to include("default-src 'self'")
      expect(policy).to include("object-src 'none'")
      expect(policy).to include("frame-ancestors 'none'")
      expect(response.headers['Content-Security-Policy']).to be_nil
    end

    # The Font Awesome kit is a Pro one: it fetches its CSS, then its fonts, from
    # ka-p.fontawesome.com.
    it "lets the Font Awesome kit load its CSS and fonts" do
      get admin_entries_path

      directives = response.headers['Content-Security-Policy-Report-Only'].split(';').map(&:strip)
      expect(directives.find { |d| d.start_with?('font-src') }).to include('https://ka-p.fontawesome.com')
      expect(directives.find { |d| d.start_with?('connect-src') }).to include('https://ka-p.fontawesome.com')
    end

    # Browsers fetch module scripts with CORS, which the public asset host
    # doesn't send, so the admin's JavaScript failed to load from there.
    context "with a public asset host" do
      around do |example|
        original = ActionController::Base.asset_host
        ActionController::Base.asset_host = 'https://cdn.example.com'
        example.run
      ensure
        ActionController::Base.asset_host = original
      end

      it "serves the admin's assets from its own host" do
        get admin_entries_path

        expect(response.body).to match(%r{<script[^>]+src="/assets/admin-[^"]+\.js"})
        expect(response.body).not_to include('https://cdn.example.com/assets/')
      end

      it "still serves public pages' assets from the asset host" do
        entry = create(:entry, :published, :with_photo, blog: blog, user: user)
        entry.photos.each { |p| attach_image_to_photo(p) }

        get entries_path

        expect(response.body).to include('src="https://cdn.example.com/assets/application-')
      end
    end
  end
end
