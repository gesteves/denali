require 'test_helper'

class Admin::CamerasControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get admin_cameras_index_url
    assert_response :success
  end

  test "should get edit" do
    get admin_cameras_edit_url
    assert_response :success
  end

  test "should get update" do
    get admin_cameras_update_url
    assert_response :success
  end

end
