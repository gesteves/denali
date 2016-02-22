require 'test_helper'

class BufferJobTest < ActiveJob::TestCase
  test 'buffer jobs should be queued if entry published' do
    queued = entries(:panda)
    assert_enqueued_with(job: BufferJob) do
      queued.publish
    end
  end
end
