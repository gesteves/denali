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
end
