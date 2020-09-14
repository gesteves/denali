require 'test_helper'

class OembedControllerTest < ActionController::TestCase
  test "oembed should work for published entries" do
    entry = entries(:peppers)
    set_up_images(entry)
    get :show, params: { url: entry.permalink_url, format: 'json' }
    assert_response :success
    assert_template :show
  end

  test "oembed should work for non-published entries" do
    entry = entries(:panda)
    set_up_images(entry)
    get :show, params: { url: entry.permalink_url, format: 'json' }
    assert_response :success
    assert_template :show
  end
end
