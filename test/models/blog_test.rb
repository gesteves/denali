require 'test_helper'

class BlogTest < ActiveSupport::TestCase
  test 'creating an entry touches the blog' do
    blog = blogs(:allencompassingtrip)
    user = users(:guille)
    initial_date = blog.updated_at
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'published', blog: blog, user: user)
    entry.save
    final_date = blog.updated_at
    assert_not_equal initial_date, final_date
  end

  test 'check count publish scheduled' do
    blog = blogs(:allencompassingtrip)

    # Travel to 12:00 am
    travel_to Time.zone.local(2019, 01, 19, 0, 0, 0)
    assert_equal 0, blog.past_publish_schedules_today.count
    assert_equal 2, blog.pending_publish_schedules_today.count

    # Travel to 8:05 am
    travel_to Time.zone.local(2019, 01, 19, 8, 5, 0)
    assert_equal 1, blog.past_publish_schedules_today.count
    assert_equal 1, blog.pending_publish_schedules_today.count

    # Travel to 6:59 pm
    travel_to Time.zone.local(2019, 01, 19, 18, 59, 0)
    assert_equal 2, blog.past_publish_schedules_today.count
    assert_equal 0, blog.pending_publish_schedules_today.count
  end

  test 'check time to publish scheduled entries' do
    blog = blogs(:allencompassingtrip)

    # Travel to 12:00 am
    travel_to Time.zone.local(2019, 01, 19, 0, 0, 0)
    assert_not blog.time_to_publish_queued_entry?

    # Travel to 8:05 am
    travel_to Time.zone.local(2019, 01, 19, 8, 5, 0)
    assert blog.time_to_publish_queued_entry?

    # Travel to 6:59 pm
    travel_to Time.zone.local(2019, 01, 19, 18, 59, 0)
    assert blog.time_to_publish_queued_entry?
  end

  test 'check publish queued entries on schedule' do
    user = users(:guille)
    blog = blogs(:allencompassingtrip)

    entry = Entry.new(title: 'test 1', status: 'queued', blog: blog, user: user)
    entry.save
    entry.move_to_top
    queue_size = blog.entries.queued.count
    assert_equal 1, entry.position

    # Travel to 12:00 am
    travel_to Time.zone.local(2019, 01, 19, 0, 0, 0)
    blog.publish_queued_entry!
    entry.reload
    assert_equal queue_size, blog.entries.queued.count
    assert_equal 'queued', entry.status

    # Travel to 8:05 am
    travel_to Time.zone.local(2019, 01, 19, 8, 5, 0)
    blog.publish_queued_entry!
    entry.reload
    assert_equal queue_size, blog.entries.queued.count + 1
    assert_equal 'published', entry.status

    # Travel to 6:59 pm
    travel_to Time.zone.local(2019, 01, 19, 18, 59, 0)
    blog.publish_queued_entry!
    entry.reload
    assert_equal queue_size, blog.entries.queued.count + 2
    assert_equal 'published', entry.status
  end

  test 'correctly identify tumblr username' do
    blog = blogs(:allencompassingtrip)

    blog.tumblr = 'https://www.tumblr.com/gesteves'
    blog.save!
    blog.reload
    assert_equal 'gesteves', blog.tumblr_username

    blog.tumblr = 'https://tumblr.com/gesteves'
    blog.save!
    blog.reload
    assert_equal 'gesteves', blog.tumblr_username

    blog.tumblr = 'https://www.tumblr.com/follow/gesteves'
    blog.save!
    blog.reload
    assert_equal 'gesteves', blog.tumblr_username

    blog.tumblr = 'https://tumblr.com/blog/gesteves'
    blog.save!
    blog.reload
    assert_equal 'gesteves', blog.tumblr_username

    blog.tumblr = 'https://gesteves.tumblr.com'
    blog.save!
    blog.reload
    assert_equal 'gesteves', blog.tumblr_username

    blog.tumblr = 'https://gesteves.tumblr.com/foo'
    blog.save!
    blog.reload
    assert_equal 'gesteves', blog.tumblr_username

    blog.tumblr = 'https://www.gesteves.com'
    blog.save!
    blog.reload
    assert_equal 'www.gesteves.com', blog.tumblr_username

    blog.tumblr = 'https://gesteves.com/'
    blog.save!
    blog.reload
    assert_equal 'gesteves.com', blog.tumblr_username

    blog.tumblr = 'https://gesteves.com/foo'
    blog.save!
    blog.reload
    assert_equal 'gesteves.com', blog.tumblr_username
  end
end
