require 'test_helper'

class RobotsControllerTest < ActionController::TestCase
  test "should generate robots" do
    get :show, format: 'txt'
    assert_template :show
    assert_response :success
  end
end
