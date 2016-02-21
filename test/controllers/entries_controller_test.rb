require 'test_helper'

class EntriesControllerTest < ActionController::TestCase
  test 'entries index should render correctly' do
    get :index
    assert_response :success
    assert_not_nil assigns(:entries)
    assert_template :index
    assert_template layout: 'layouts/application'
    assert_select '.entry-list' do
      assert_select '.entry-list__item', 2
    end
  end

  test 'photo page should render correctly' do
    entry = entries(:peppers)
    get :show, year: entry.published_at.strftime('%Y'), month: entry.published_at.strftime('%-m'), day: entry.published_at.strftime('%-d'), id: entry.id, slug: entry.slug
    assert_response :success
    assert_not_nil assigns(:entry)
    assert_template :show
    assert_template layout: 'layouts/application'
    assert_select '.entry', 1
    assert_select '.entry__photo', 1
    assert_select '.entry__image', 1
    assert_select '.entry__headline', 1
  end
end
