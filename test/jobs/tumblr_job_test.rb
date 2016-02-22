require 'test_helper'

class TumblrJobTest < ActiveJob::TestCase
  test 'tumblr jobs should be queued if entry published' do
    published = entries(:peppers)
    assert_enqueued_with(job: TumblrJob) do
      published.enqueue_jobs
    end
  end
end
