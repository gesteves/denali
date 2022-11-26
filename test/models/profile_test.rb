require "test_helper"

class ProfileTest < ActiveSupport::TestCase
  test 'correctly identify tumblr username' do
    profile = profiles(:guille)

    profile.tumblr = 'https://www.tumblr.com/gesteves'
    profile.save!
    profile.reload
    assert_equal 'gesteves', profile.tumblr_username

    profile.tumblr = 'https://tumblr.com/gesteves'
    profile.save!
    profile.reload
    assert_equal 'gesteves', profile.tumblr_username

    profile.tumblr = 'https://www.tumblr.com/follow/gesteves'
    profile.save!
    profile.reload
    assert_equal 'gesteves', profile.tumblr_username

    profile.tumblr = 'https://tumblr.com/profile/gesteves'
    profile.save!
    profile.reload
    assert_equal 'gesteves', profile.tumblr_username

    profile.tumblr = 'https://gesteves.tumblr.com'
    profile.save!
    profile.reload
    assert_equal 'gesteves', profile.tumblr_username

    profile.tumblr = 'https://gesteves.tumblr.com/foo'
    profile.save!
    profile.reload
    assert_equal 'gesteves', profile.tumblr_username

    profile.tumblr = 'https://www.gesteves.com'
    profile.save!
    profile.reload
    assert_equal 'www.gesteves.com', profile.tumblr_username

    profile.tumblr = 'https://gesteves.com/'
    profile.save!
    profile.reload
    assert_equal 'gesteves.com', profile.tumblr_username

    profile.tumblr = 'https://gesteves.com/foo'
    profile.save!
    profile.reload
    assert_equal 'gesteves.com', profile.tumblr_username
  end
end
