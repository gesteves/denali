require 'test_helper'

class EntriesControllerTest < ActionController::TestCase
  test 'entries index should render correctly' do
    get :index
    assert_response :success
    assert_not_nil assigns(:entries)
    assert_template layout: 'layouts/application'
    assert_template :index
    assert_select '.entry-list' do
      assert_select '.entry-list__item', 2
    end
  end

  test "should generate index json" do
    get :index, format: 'json'
    assert_template :index
    assert_response :success
  end

  test "should generate sitemap" do
    get :sitemap, format: 'xml'
    assert_template :sitemap
    assert_response :success
  end

  test "should generate feed" do
    get :rss, format: 'xml'
    assert_template :rss
    assert_response :success
  end

  test 'photo page should render correctly' do
    entry = entries(:peppers)
    get :show, year: entry.published_at.strftime('%Y'), month: entry.published_at.strftime('%-m'), day: entry.published_at.strftime('%-d'), id: entry.id, slug: entry.slug
    assert_response :success
    assert_not_nil assigns(:entry)
    assert_template layout: 'layouts/application'
    assert_template :show
    assert_select '.entry', 1
    assert_select '.entry__photo', 1
    assert_select '.entry__image', 1
    assert_select '.entry__headline', 1
  end

  test 'should redirect from tumblr url' do
    get :tumblr, tumblr_id: '17444976847'
    entry = entries(:peppers)
    assert_not_nil assigns(:entry)
    assert_equal assigns(:entry), entry
    assert_redirected_to entry_long_url(year: entry.published_at.strftime('%Y'), month: entry.published_at.strftime('%-m'), day: entry.published_at.strftime('%-d'), id: entry.id, slug: entry.slug)
  end
end
