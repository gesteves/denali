require 'test_helper'

class Admin::LensesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get admin_lenses_index_url
    assert_response :success
  end

  test "should get edit" do
    get admin_lenses_edit_url
    assert_response :success
  end

  test "should get update" do
    get admin_lenses_update_url
    assert_response :success
  end

end
