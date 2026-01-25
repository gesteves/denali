require 'rails_helper'

RSpec.describe "Blogs", type: :request do
  let!(:blog) { Blog.first || create(:blog, about: 'About this blog') }

  describe "GET /about" do
    it "renders successfully" do
      get about_path
      expect(response).to have_http_status(:success)
    end

    it "displays the about page title" do
      get about_path
      expect(response.body).to include("About")
    end

    it "displays the blog's about content" do
      get about_path
      expect(response.body).to include(blog.about) if blog.about.present?
    end
  end
end
