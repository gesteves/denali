require "test_helper"

class SitemapsControllerTest < ActionController::TestCase
  test "should generate entries sitemap" do
    get :entries, params: { format: 'xml', page: 1 }
    assert_template :entries
    assert_response :success
  end

  test "should generate sitemap index" do
    get :index, params: { format: 'xml' }
    assert_template :index
    assert_response :success
  end

  test "entries sitemap should include image namespace" do
    get :entries, params: { format: 'xml', page: 1 }
    assert_response :success
    assert_includes @response.body, 'xmlns:image="http://www.google.com/schemas/sitemap-image/1.1"'
  end

  test "entries sitemap should include image:image elements for entries with photos" do
    get :entries, params: { format: 'xml', page: 1 }
    assert_response :success
    assert_includes @response.body, '<image:image>'
    assert_includes @response.body, '<image:loc>'
  end
end
