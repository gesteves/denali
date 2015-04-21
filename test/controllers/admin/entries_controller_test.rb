require 'test_helper'

class Admin::EntriesControllerTest < ActionController::TestCase
  setup do
    @admin_entry = admin_entries(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:admin_entries)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create admin_entry" do
    assert_difference('Admin::Entry.count') do
      post :create, admin_entry: {  }
    end

    assert_redirected_to admin_entry_path(assigns(:admin_entry))
  end

  test "should show admin_entry" do
    get :show, id: @admin_entry
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @admin_entry
    assert_response :success
  end

  test "should update admin_entry" do
    patch :update, id: @admin_entry, admin_entry: {  }
    assert_redirected_to admin_entry_path(assigns(:admin_entry))
  end

  test "should destroy admin_entry" do
    assert_difference('Admin::Entry.count', -1) do
      delete :destroy, id: @admin_entry
    end

    assert_redirected_to admin_entries_path
  end
end
