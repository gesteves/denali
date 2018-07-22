require 'test_helper'

class Admin::LensesControllerTest < ActionController::TestCase
  test 'should redirect to sign in page if not signed in' do
    get :edit, params: { id: lenses(:xf23mm).id }
    assert_redirected_to signin_path
  end

  test 'should render edit page' do
    session[:user_id] = users(:guille).id
    get :edit, params: { id: lenses(:xf23mm).id }
    assert_response :success
    assert_template layout: 'layouts/admin'
    assert_template :edit
  end

  test 'should update lenses' do
    session[:user_id] = users(:guille).id
    lens = lenses(:xf23mm)
    patch :update, params: { id: lens.id, lens: { id: lens.id } }
    assert_redirected_to admin_equipment_path
  end
end
