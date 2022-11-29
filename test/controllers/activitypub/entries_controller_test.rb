require "test_helper"

class Activitypub::EntriesControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get activitypub_entries_show_url
    assert_response :success
  end
end
