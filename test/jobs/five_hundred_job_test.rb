require 'test_helper'

class FiveHundredJobTest < ActiveJob::TestCase
  test '500px jobs should be queued if entry published' do
    published = entries(:peppers)
    assert_enqueued_with(job: FiveHundredJob) do
      published.enqueue_jobs
    end
  end
end
