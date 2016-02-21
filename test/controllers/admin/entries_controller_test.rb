require 'test_helper'

class Admin::EntriesControllerTest < ActionController::TestCase
  test 'should render preview page' do
    entry = entries(:panda)
    get :preview, id: entry.id
    assert_response :success
    assert_template layout: 'layouts/application'
    assert_template :show
  end

  test 'should redirect published photos from preview page' do
    entry = entries(:peppers)
    get :preview, id: entry.id
    assert_redirected_to entry_long_url(year: entry.published_at.strftime('%Y'), month: entry.published_at.strftime('%-m'), day: entry.published_at.strftime('%-d'), id: entry.id, slug: entry.slug)
  end

  test 'should redirect to sign in page if not signed in' do
    entry = entries(:peppers)
    entry.tag_list = 'washington'
    entry.save
    get :index
    assert_redirected_to signin_path
    get :queued
    assert_redirected_to signin_path
    get :drafts
    assert_redirected_to signin_path
    get :tagged, tag: 'washington'
    assert_redirected_to signin_path
    get :new
    assert_redirected_to signin_path
    get :edit, id: entry.id
    assert_redirected_to signin_path
    get :share, id: entry.id
    assert_redirected_to signin_path
  end

  test 'should render entries page' do
    session[:user_id] = users(:guille).id
    get :index
    assert_response :success
    assert_template layout: 'layouts/admin'
    assert_template :index
  end

  test 'should render queued page' do
    session[:user_id] = users(:guille).id
    get :queued
    assert_response :success
    assert_template layout: 'layouts/admin'
    assert_template :queued
  end

  test 'should render drafts page' do
    session[:user_id] = users(:guille).id
    get :drafts
    assert_response :success
    assert_template layout: 'layouts/admin'
    assert_template :drafts
  end

  test 'should render tag page' do
    session[:user_id] = users(:guille).id
    entry = entries(:peppers)
    entry.tag_list = 'washington'
    entry.save
    get :tagged, tag: 'washington'
    assert_response :success
    assert_not_nil assigns(:entries)
    assert_template layout: 'layouts/admin'
    assert_template :tagged
  end

  test 'should render new entry page' do
    session[:user_id] = users(:guille).id
    get :new
    assert_response :success
    assert_template layout: 'layouts/admin'
    assert_template :new
  end

  test 'should render edit entry page' do
    session[:user_id] = users(:guille).id
    entry = entries(:peppers)
    get :edit, id: entry.id
    assert_not_nil assigns(:entry)
    assert_response :success
    assert_template layout: 'layouts/admin'
    assert_template :edit
  end

  test 'should render share entry page' do
    session[:user_id] = users(:guille).id
    entry = entries(:peppers)
    get :share, id: entry.id
    assert_not_nil assigns(:entry)
    assert_response :success
    assert_template layout: 'layouts/admin'
    assert_template :share
  end
end
