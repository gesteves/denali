require 'test_helper'

class Admin::CamerasControllerTest < ActionController::TestCase
  test 'should redirect to sign in page if not signed in' do
    get :index
    assert_redirected_to signin_path
  end

  test 'should render index page' do
    session[:user_id] = users(:guille).id
    get :index
    assert_response :success
    assert_template layout: 'layouts/admin'
    assert_template :index
  end

  test 'should render edit page' do
    session[:user_id] = users(:guille).id
    get :edit, params: { id: cameras(:xz1).id }
    assert_response :success
    assert_template layout: 'layouts/admin'
    assert_template :edit
  end

  test 'should update cameras' do
    session[:user_id] = users(:guille).id
    camera = cameras(:xz1)
    patch :update, params: { id: camera.id, camera: { id: camera.id } }
    assert_redirected_to admin_cameras_path
  end
end
