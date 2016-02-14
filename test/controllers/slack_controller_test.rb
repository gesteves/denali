require 'test_helper'

class SlackControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
  end

end
