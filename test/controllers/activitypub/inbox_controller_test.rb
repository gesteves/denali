require "test_helper"

class Activitypub::InboxControllerTest < ActionController::TestCase
  test "should get inbox" do
    username = profiles(:guille).username
    get activitypub_inbox_url(username: username)
    assert_response :success
  end
end
