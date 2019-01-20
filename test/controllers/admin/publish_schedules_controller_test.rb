require 'test_helper'

class Admin::PublishSchedulesControllerTest < ActionController::TestCase
  def setup
    session[:user_id] = users(:guille).id
    super
  end

  test "should get index" do
    get :index
    assert_template :index
    assert_response :success
  end
end
