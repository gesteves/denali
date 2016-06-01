require 'test_helper'

class SlackControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_template layout: 'layouts/application'
    assert_template :index
    assert_response :success
  end

  test "shouldn't be cached" do
    get :index
    assert_equal @response['Cache-Control'], 'no-cache'
  end
end
