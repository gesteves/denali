require 'test_helper'

class Admin::BlogsControllerTest < ActionController::TestCase
  setup do
    @admin_blog = admin_blogs(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:admin_blogs)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create admin_blog" do
    assert_difference('Admin::Blog.count') do
      post :create, admin_blog: {  }
    end

    assert_redirected_to admin_blog_path(assigns(:admin_blog))
  end

  test "should show admin_blog" do
    get :show, id: @admin_blog
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @admin_blog
    assert_response :success
  end

  test "should update admin_blog" do
    patch :update, id: @admin_blog, admin_blog: {  }
    assert_redirected_to admin_blog_path(assigns(:admin_blog))
  end

  test "should destroy admin_blog" do
    assert_difference('Admin::Blog.count', -1) do
      delete :destroy, id: @admin_blog
    end

    assert_redirected_to admin_blogs_path
  end
end
