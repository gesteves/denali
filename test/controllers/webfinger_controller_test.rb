require "test_helper"

class WebfingerControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get webfinger_show_url
    assert_response :success
  end
end
