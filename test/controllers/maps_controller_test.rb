require 'test_helper'

class MapsControllerTest < ActionController::TestCase
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

end
