require 'test_helper'

class EntriesControllerTest < ActionController::TestCase

  test 'entries index should render correctly' do
    get :index
    assert_response :success
    assert_not_nil assigns(:entries)
    assert_template layout: 'layouts/application'
    assert_template :index
    assert_select '.entry-list' do
      assert_select '.entry-list__item', 3
    end
  end

  test 'entries index should redirect from unknown format' do
    get :index, params: { format: 'foo' }
    assert_redirected_to entries_url
  end

  test "should generate atom feed" do
    set_up_all_images
    get :feed, params: { format: 'atom' }
    assert_template :feed
    assert_response :success
  end

  test "should generate rss feed" do
    set_up_all_images
    get :feed, params: { format: 'rss' }
    assert_template :feed
    assert_response :success
  end

  test "should redirect to atom feed from unknown format" do
    get :feed, params: { format: 'foo' }
    assert_redirected_to feed_url(format: 'atom', page: nil)
  end

  test 'photo page should render correctly' do
    entry = entries(:peppers)
    set_up_images(entry)
    get :show, params: { id: entry.id, slug: entry.slug }
    assert_response :success
    assert_not_nil assigns(:entry)
    assert_template layout: 'layouts/application'
    assert_template :show
    assert_select '.entry', 1
    assert_select '.entry__photo', 1
    assert_select '.entry__figure', 1
    assert_select '.entry__headline', 1
  end

  test 'photo amp page should redirect to canonical page' do
    entry = entries(:peppers)
    get :amp, params: { year: entry.published_at.strftime('%Y'), month: entry.published_at.strftime('%-m'), day: entry.published_at.strftime('%-d'), id: entry.id, slug: entry.slug }
    assert_redirected_to entry.permalink_url
  end

  test 'photo legacy URLs page should redirect to canonical page' do
    entry = entries(:peppers)
    get :show, params: { year: entry.published_at.strftime('%Y'), month: entry.published_at.strftime('%-m'), day: entry.published_at.strftime('%-d'), id: entry.id, slug: entry.slug }
    assert_redirected_to entry.permalink_url
  end

  test 'should preview page' do
    panda = entries(:panda)
    set_up_images(panda)
    get :show, params: { preview_hash: panda.preview_hash, slug: panda.slug }
    assert_response :success
    assert_template :show
  end

  test 'should render related entries' do
    peppers = entries(:peppers)
    get :related, params: { id: peppers.id, format: 'js' }
    assert_response :success
    assert_template :related
  end

  test 'should render related entries for previews' do
    panda = entries(:panda)
    get :related, params: { preview_hash: panda.preview_hash, format: 'js' }
    assert_response :success
    assert_template :related
  end

  test 'should redirect related entries previews if entry published' do
    peppers = entries(:peppers)
    get :related, params: { preview_hash: peppers.preview_hash, format: 'js' }
    assert_redirected_to related_url(peppers, format: 'js')
  end

  test 'should redirect published photos from preview page' do
    entry = entries(:peppers)
    set_up_images(entry)
    get :show, params: { preview_hash: entry.preview_hash }
    assert_redirected_to entry.permalink_url
  end

  test 'should redirect from unknown format' do
    entry = entries(:peppers)
    get :show, params: { id: entry.id, slug: entry.slug, format: 'foo' }
    assert_redirected_to entry.permalink_url
  end

  test 'should render tag page' do
    entry = entries(:peppers)
    entry.tag_list = 'washington'
    entry.save
    get :tagged, params: { tag: 'washington' }
    assert_response :success
    assert_not_nil assigns(:entries)
    assert_template layout: 'layouts/application'
    assert_template :index
    assert_select '.entry-list' do
      assert_select '.entry-list__item', 1
    end
  end

  test 'should redirect tag page from unknown format' do
    entry = entries(:peppers)
    entry.tag_list = 'washington'
    entry.save
    get :tagged, params: { tag: 'washington', format: 'foo' }
    assert_redirected_to tag_url(format: 'html', page: nil, tag: 'washington')
  end

  test 'should render tag atom feed' do
    entry = entries(:peppers)
    entry.tag_list = 'washington'
    entry.save
    set_up_images(entry)
    get :tag_feed, params: { tag: 'washington', format: 'atom' }
    assert_template :tag_feed
    assert_response :success
  end

  test 'should render tag rss feed' do
    entry = entries(:peppers)
    entry.tag_list = 'washington'
    entry.save
    set_up_images(entry)
    get :tag_feed, params: { tag: 'washington', format: 'rss' }
    assert_template :tag_feed
    assert_response :success
  end

  test 'should redirect tag feed from unknown format' do
    entry = entries(:peppers)
    entry.tag_list = 'washington'
    entry.save
    get :tag_feed, params: { tag: 'washington', format: 'foo' }
    assert_redirected_to tag_feed_url(format: 'atom', page: nil, tag: 'washington')
  end
end
