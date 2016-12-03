require 'test_helper'

class Admin::TagsControllerTest < ActionController::TestCase
  def setup
    session[:user_id] = users(:guille).id
    @entry = entries(:peppers)
    @entry.tag_list = 'washington'
    @entry.save
  end

  test "should get index" do
    get :index
    assert_response :success
  end

  test "should destroy tags" do
    entry = entries(:peppers)
    entry.tag_list = 'foo, bar'
    entry.save

    tag = ActsAsTaggableOn::Tag.where(name: 'foo').first
    delete :destroy, params: { id: tag.id }

    entry.reload
    assert_not_includes entry.tag_list, 'foo'
    assert_not_empty entry.tag_list

    tag = ActsAsTaggableOn::Tag.where(name: 'bar').first
    delete :destroy, params: { id: tag.id }

    entry.reload
    assert_not_includes entry.tag_list, 'bar'
    assert_empty entry.tag_list
  end

end
