require "test_helper"

class Activitypub::OutboxControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get activitypub_outbox_index_url
    assert_response :success
  end
end
