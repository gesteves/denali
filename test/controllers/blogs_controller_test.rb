require 'test_helper'

class BlogsControllerTest < ActionController::TestCase
  test "should get about" do
    get :about
    assert_response :success
    assert_template layout: 'layouts/application'
    assert_template :about
  end

  test "should get manifest" do
    get :manifest
    assert_response :success
  end

  test "should get offline" do
    get :offline
    assert_response :success
  end
end
