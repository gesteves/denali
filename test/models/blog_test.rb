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

  test 'queued entries published per day' do
    blog = blogs(:allencompassingtrip)
    assert_equal 2, blog.queued_entries_published_per_day
  end

  test 'check time to publish scheduled entries' do
    blog = blogs(:allencompassingtrip)

    # Travel to saturday at 12:00 am
    travel_to Time.zone.local(2019, 01, 19, 0, 0, 0)
    assert_not blog.time_to_publish_queued_entry?

    # Travel to saturday at 8:00 am
    travel_to Time.zone.local(2019, 01, 19, 8, 0, 0)
    assert_not blog.time_to_publish_queued_entry?

    # Travel to saturday at 6:00 pm
    travel_to Time.zone.local(2019, 01, 19, 18, 0, 0)
    assert_not blog.time_to_publish_queued_entry?

    # Travel to sunday at 12:00 am
    travel_to Time.zone.local(2019, 01, 20, 0, 0, 0)
    assert_not blog.time_to_publish_queued_entry?

    # Travel to sunday at 8:00 am
    travel_to Time.zone.local(2019, 01, 20, 8, 0, 0)
    assert blog.time_to_publish_queued_entry?

    # Travel to sunday at 8:59 am
    travel_to Time.zone.local(2019, 01, 20, 8, 59, 0)
    assert blog.time_to_publish_queued_entry?

    # Travel to sunday at 6:00 pm
    travel_to Time.zone.local(2019, 01, 20, 18, 0, 0)
    assert_not blog.time_to_publish_queued_entry?

    # Travel to monday at 12:00 am
    travel_to Time.zone.local(2019, 01, 21, 0, 0, 0)
    assert_not blog.time_to_publish_queued_entry?

    # Travel to monday at 8:00 am
    travel_to Time.zone.local(2019, 01, 21, 8, 0, 0)
    assert_not blog.time_to_publish_queued_entry?

    # Travel to monday at 8:59 am
    travel_to Time.zone.local(2019, 01, 21, 8, 59, 0)
    assert_not blog.time_to_publish_queued_entry?

    # Travel to monday at 6:00 pm
    travel_to Time.zone.local(2019, 01, 21, 18, 0, 0)
    assert blog.time_to_publish_queued_entry?

    # Travel to monday at 6:01 pm
    travel_to Time.zone.local(2019, 01, 21, 18, 1, 0)
    assert blog.time_to_publish_queued_entry?
  end

  test 'check publish queued entries on schedule' do
    user = users(:guille)
    blog = blogs(:allencompassingtrip)

    entry = Entry.new(title: 'test 1', status: 'queued', blog: blog, user: user)
    entry.save
    entry.move_to_top
    queue_size = blog.entries.queued.count
    assert_equal entry.position, 1

    # Travel to saturday at 12:00 am
    travel_to Time.zone.local(2019, 01, 19, 0, 0, 0)
    blog.publish_queued_entry!
    entry.reload
    assert_equal queue_size, blog.entries.queued.count
    assert_equal 'queued', entry.status

    # Travel to saturday at 8:00 am
    travel_to Time.zone.local(2019, 01, 19, 8, 0, 0)
    blog.publish_queued_entry!
    entry.reload
    assert_equal queue_size, blog.entries.queued.count
    assert_equal 'queued', entry.status

    # Travel to saturday at 6:00 pm
    travel_to Time.zone.local(2019, 01, 19, 18, 0, 0)
    blog.publish_queued_entry!
    entry.reload
    assert_equal queue_size, blog.entries.queued.count
    assert_equal 'queued', entry.status

    # Travel to Sunday at 6:00 pm
    travel_to Time.zone.local(2019, 01, 20, 18, 0, 0)
    blog.publish_queued_entry!
    entry.reload
    assert_equal queue_size, blog.entries.queued.count
    assert_equal 'queued', entry.status

    # Travel to Sunday at 8:00 am
    travel_to Time.zone.local(2019, 01, 20, 8, 0, 0)
    blog.publish_queued_entry!
    entry.reload
    assert_equal queue_size, blog.entries.queued.count + 1
    assert_equal 'published', entry.status
  end
end
