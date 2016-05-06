require 'test_helper'

class PinterestJobTest < ActiveJob::TestCase
  test 'pinterest jobs should be queued if entry published' do
    queued = entries(:panda)
    assert_enqueued_with(job: PinterestJob) do
      queued.publish
    end
  end
end
