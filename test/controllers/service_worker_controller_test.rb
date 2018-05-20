require 'test_helper'

class ServiceWorkerControllerTest < ActionController::TestCase
  test "should get service_worker" do
    get :index
    assert_response :success
  end
end
