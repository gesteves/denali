require 'test_helper'

class InstagramJobTest < ActiveJob::TestCase
  test 'instagram jobs should be queued if entry published' do
    queued = entries(:panda)
    assert_enqueued_with(job: InstagramJob) do
      queued.publish
    end
  end
end
