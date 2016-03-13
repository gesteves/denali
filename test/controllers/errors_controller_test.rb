require 'test_helper'

class ErrorsControllerTest < ActionController::TestCase
  test 'should render 404 page' do
    get :file_not_found
    assert_response 404
    assert_template layout: 'layouts/application'
    assert_template :error
  end

  test 'should render 422 page' do
    get :unprocessable
    assert_response 422
    assert_template layout: 'layouts/application'
    assert_template :error
  end

  test 'should render 500 page' do
    get :internal_server_error
    assert_response 500
    assert_template layout: 'layouts/application'
    assert_template :error
  end
end
