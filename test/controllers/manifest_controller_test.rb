require "test_helper"

class ManifestControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get manifest_index_url
    assert_response :success
  end
end
