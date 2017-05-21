require 'test_helper'

class ProgressiveWebAppControllerTest < ActionController::TestCase
  test "should get service_worker" do
    get :service_worker
    assert_response :success
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
