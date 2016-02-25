require 'test_helper'

class OembedControllerTest < ActionController::TestCase
  test "should get show" do
    get :show, url: entries(:peppers).permalink_url
    assert_response :success
  end

end
