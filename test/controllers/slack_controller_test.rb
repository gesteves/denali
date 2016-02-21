require 'test_helper'

class SlackControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_template :index
    assert_response :success
  end

  test "should redirect to index index" do
    get :index, state: 123
    assert_redirected_to slack_path
  end

end
