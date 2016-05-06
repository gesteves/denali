require 'test_helper'

class Admin::SlackIncomingWebhooksControllerTest < ActionController::TestCase
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
end
