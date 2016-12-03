require 'test_helper'

class Admin::BlogsControllerTest < ActionController::TestCase
  test 'should redirect to sign in page if not signed in' do
    get :edit
    assert_redirected_to signin_path
  end

  test 'should render edit page' do
    session[:user_id] = users(:guille).id
    get :edit
    assert_response :success
    assert_template layout: 'layouts/admin'
    assert_template :edit
  end

  test 'should update blog' do
    session[:user_id] = users(:guille).id
    patch :update, params: { blog: { id: blogs(:allencompassingtrip).id } }
    assert_redirected_to admin_settings_path
  end
end
