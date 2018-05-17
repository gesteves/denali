require 'test_helper'

class OembedControllerTest < ActionController::TestCase
  test "oembed should work for published entries" do
    get :show, params: { url: entries(:peppers).permalink_url }
    assert_response :success
    assert_template :show
  end

  test "oembed should work for non-published entries" do
    get :show, params: { url: entries(:panda).permalink_url }
    assert_response :success
    assert_template :show
  end

end
