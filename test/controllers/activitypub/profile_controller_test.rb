require "test_helper"

class Activitypub::ProfileControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get activitypub_profile_show_url
    assert_response :success
  end
end
