require 'test_helper'

class OembedControllerTest < ActionController::TestCase
  test "should get show" do
    get :show, params: { url: entries(:peppers).permalink_url }
    assert_response :success
    assert_template :show
  end

end
