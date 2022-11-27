require "test_helper"

class Activitypub::ProfileControllerTest < ActionController::TestCase
  test "should get profile" do
    username = profiles(:guille).username
    get activitypub_profile_url(username: username)
    assert_response :success

    get activitypub_profile_url(username: 'foo')
    assert_response :not_found
  end
end
