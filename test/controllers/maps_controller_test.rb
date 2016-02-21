require 'test_helper'

class MapsControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
  end

  test "should generate json" do
    get :photos, format: 'json'
    assert_template :photos
    assert_response :success
  end

  test "should only return mapped images" do
    get :photos, format: 'json'
    json = JSON.parse(@response.body)
    assert_not_empty json.select { |e| e['properties']['title'] == entries(:peppers).title }
    assert_empty json.select { |e| e['properties']['title'] == entries(:potomac).title }
  end

end
