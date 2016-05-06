require 'test_helper'

class Admin::TagsControllerTest < ActionController::TestCase
  def setup
    session[:user_id] = users(:guille).id
  end

  test "should get index" do
    get :index
    assert_response :success
  end

end
