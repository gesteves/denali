require 'test_helper'

class AdminControllerTest < ActionController::TestCase
  test 'should redirect to sign in page if not signed in' do
    get :index
    assert_redirected_to signin_path
  end

  test 'should redirect to admin entries list' do
    session[:user_id] = users(:guille).id
    get :index
    assert_redirected_to admin_entries_path
  end
end
