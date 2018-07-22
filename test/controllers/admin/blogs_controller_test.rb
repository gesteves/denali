require 'test_helper'

class Admin::BlogsControllerTest < ActionController::TestCase
  test 'should redirect to sign in page if not signed in' do
    get :edit, params: { id: blogs(:allencompassingtrip).id }
    assert_redirected_to signin_path
  end

  test 'should render edit page' do
    session[:user_id] = users(:guille).id
    get :edit, params: { id: blogs(:allencompassingtrip).id }
    assert_response :success
    assert_template layout: 'layouts/admin'
    assert_template :edit
  end

  test 'should update blog' do
    session[:user_id] = users(:guille).id
    blog = blogs(:allencompassingtrip)
    patch :update, params: { id: blog.id, blog: { id: blog.id } }
    assert_redirected_to edit_admin_blog_path(blog.id)
  end
end
