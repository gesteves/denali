require 'test_helper'

class TwitterJobTest < ActiveJob::TestCase
  test 'twitter jobs should be queued if entry published' do
    published = entries(:peppers)
    assert_enqueued_with(job: TwitterJob) do
      published.enqueue_jobs
    end
  end

  test 'jobs shouldnt be queued if entry is queued' do
    queued = entries(:panda)
    queued.enqueue_jobs
    assert_enqueued_jobs 0
  end
end
