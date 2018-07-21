require 'test_helper'

class Admin::FilmsControllerTest < ActionController::TestCase
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

  test 'should render edit page' do
    session[:user_id] = users(:guille).id
    get :edit, params: { id: films(:portra).id }
    assert_response :success
    assert_template layout: 'layouts/admin'
    assert_template :edit
  end

  test 'should update films' do
    session[:user_id] = users(:guille).id
    film = films(:portra)
    patch :update, params: { id: film.id, film: { id: film.id } }
    assert_redirected_to admin_films_path
  end
end
