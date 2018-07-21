require 'test_helper'

class Admin::FilmsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get admin_films_index_url
    assert_response :success
  end

  test "should get edit" do
    get admin_films_edit_url
    assert_response :success
  end

  test "should get update" do
    get admin_films_update_url
    assert_response :success
  end

end
