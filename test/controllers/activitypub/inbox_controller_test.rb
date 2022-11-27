require "test_helper"

class Activitypub::InboxControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get activitypub_inbox_index_url
    assert_response :success
  end
end
