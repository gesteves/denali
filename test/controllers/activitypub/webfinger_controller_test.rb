require "test_helper"

class Activitypub::WebfingerControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get activitypub_webfinger_show_url
    assert_response :success
  end
end
