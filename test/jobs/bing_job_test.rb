require 'test_helper'

class BingJobTest < ActiveJob::TestCase
  test 'bing jobs should be queued if entry published' do
    queued = entries(:panda)
    assert_enqueued_with(job: BingJob) do
      queued.publish
    end
  end
end
