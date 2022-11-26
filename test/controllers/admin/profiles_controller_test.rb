require "test_helper"

class Admin::ProfilesControllerTest < ActionDispatch::IntegrationTest
  test "should get edit" do
    get admin_profiles_edit_url
    assert_response :success
  end

  test "should get update" do
    get admin_profiles_update_url
    assert_response :success
  end
end
