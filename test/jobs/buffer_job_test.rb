require 'test_helper'

class BufferJobTest < ActiveJob::TestCase
  test 'buffer jobs should be queued if entry published' do
    published = entries(:peppers)
    assert_enqueued_with(job: BufferJob) do
      published.enqueue_jobs
    end
  end
end
