require 'test_helper'

class Admin::PhotosControllerTest < ActionController::TestCase
  def setup
    session[:user_id] = users(:guille).id
  end

  test 'should render photos page' do
    get :index
    assert_response :success
    assert_template layout: 'layouts/admin'
    assert_template :index
  end
end
