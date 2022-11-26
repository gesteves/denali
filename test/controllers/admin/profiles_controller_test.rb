require "test_helper"

class Admin::ProfilesControllerTest < ActionDispatch::IntegrationTest
  test 'should redirect to sign in page if not signed in' do
    get :edit, params: { id: profiles(:guille).id }
    assert_redirected_to signin_path
  end

  test 'should render edit page' do
    session[:user_id] = users(:guille).id
    get :edit, params: { id: profiles(:guille).id }
    assert_response :success
    assert_template layout: 'layouts/admin'
    assert_template :edit
  end

  test 'should update blog' do
    session[:user_id] = users(:guille).id
    profile = profiles(:guille)
    patch :update, params: { id: profile.id, profile: { id: profile.id } }
    assert_redirected_to edit_admin_profile_path(profile.id)
  end
end
