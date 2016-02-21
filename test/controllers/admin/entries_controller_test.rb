require 'test_helper'

class Admin::EntriesControllerTest < ActionController::TestCase

  def setup
    session[:user_id] = users(:guille).id
  end

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
    assert_redirected_to entry.permalink_url
  end

  test 'should render entries page' do
    get :index
    assert_response :success
    assert_template layout: 'layouts/admin'
    assert_template :index
  end

  test 'should render queued page' do
    get :queued
    assert_response :success
    assert_template layout: 'layouts/admin'
    assert_template :queued
  end

  test 'should render drafts page' do
    get :drafts
    assert_response :success
    assert_template layout: 'layouts/admin'
    assert_template :drafts
  end

  test 'should render tag page' do
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
    get :new
    assert_response :success
    assert_template layout: 'layouts/admin'
    assert_template :new
  end

  test 'should render edit entry page' do
    entry = entries(:peppers)
    get :edit, id: entry.id
    assert_not_nil assigns(:entry)
    assert_response :success
    assert_template layout: 'layouts/admin'
    assert_template :edit
  end

  test 'should render share entry page' do
    entry = entries(:peppers)
    get :share, id: entry.id
    assert_not_nil assigns(:entry)
    assert_response :success
    assert_template layout: 'layouts/admin'
    assert_template :share
  end
end
