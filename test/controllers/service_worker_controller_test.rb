require 'test_helper'

class ServiceWorkerControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get service_worker_index_url
    assert_response :success
  end

end
