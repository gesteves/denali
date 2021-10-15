require "test_helper"

class SitemapsControllerTest < ActionController::TestCase
  test "should generate entries sitemap" do
    get :entries, params: { format: 'xml', page: 1 }
    assert_template :entries
    assert_response :success
  end

  test "should generate tags sitemap" do
    entry = entries(:peppers)
    entry.tag_list = 'test'
    entry.save

    get :tags, params: { format: 'xml', page: 1 }
    assert_template :tags
    assert_response :success
  end

  test "should generate sitemap index" do
    get :index, params: { format: 'xml' }
    assert_template :index
    assert_response :success
  end
end
