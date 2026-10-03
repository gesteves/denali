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
  end
end
