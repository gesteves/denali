require "test_helper"

class Activitypub::ActivitiesControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get activitypub_activities_show_url
    assert_response :success
  end
end
