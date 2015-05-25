require 'test_helper'

class EntriesControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
  end

  test "should get show" do
    get :show
    assert_response :success
  end

  test "should get tumblr" do
    get :tumblr
    assert_response :success
  end

  test "should get tagged" do
    get :tagged
    assert_response :success
  end

  test "should get rss" do
    get :rss
    assert_response :success
  end

end
