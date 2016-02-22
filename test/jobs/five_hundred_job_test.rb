require 'test_helper'

class FiveHundredJobTest < ActiveJob::TestCase
  test '500px jobs should be queued if entry published' do
    queued = entries(:panda)
    assert_enqueued_with(job: FiveHundredJob) do
      queued.publish
    end
  end
end
