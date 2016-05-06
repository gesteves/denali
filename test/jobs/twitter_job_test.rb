require 'test_helper'

class TwitterJobTest < ActiveJob::TestCase
  test 'jobs shouldnt be queued if entry is queued' do
    queued = entries(:panda)
    queued.enqueue_jobs
    assert_enqueued_jobs 0
  end

  test 'twitter jobs should be queued if entry published' do
    queued = entries(:panda)
    assert_enqueued_with(job: TwitterJob) do
      queued.publish
    end
  end
end
