require "test_helper"

class Activitypub::OutboxControllerTest < ActionController::TestCase
  test "should get outbox" do
    username = profiles(:guille).username
    get activitypub_outbox_url(username: username)
    assert_response :success
  end
end
