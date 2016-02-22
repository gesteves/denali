require 'test_helper'

class SlackJobTest < ActiveJob::TestCase
  test 'slack jobs should be queued if entry published' do
    published = entries(:peppers)
    assert_enqueued_with(job: SlackJob) do
      published.enqueue_jobs
    end
  end
end
