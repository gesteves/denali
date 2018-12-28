require 'test_helper'

class Admin::MapsControllerTest < ActionController::TestCase

  def setup
    session[:user_id] = users(:guille).id
    super
  end

  test "should get index" do
    get :index
    assert_template :index
    assert_response :success
  end

  test "should generate json" do
    get :photos, params: { format: 'json' }
    assert_template :photos
    assert_response :success
  end

  test "should only return mapped images" do
    get :photos, params: { format: 'json' }
    json = JSON.parse(@response.body)
    assert_not_empty json.select { |e| e['properties']['id'] == photos(:peppers).id }
    assert_empty json.select { |e| e['properties']['id'] == photos(:potomac).id }
  end

  test "should generate photo json" do
    get :photo, params: { id: photos(:peppers).id, format: 'json' }
    assert_template :photo
    assert_response :success
  end

end
