require 'test_helper'

class GoogleJobTest < ActiveJob::TestCase
  test 'google jobs should be queued if entry published' do
    queued = entries(:panda)
    assert_enqueued_with(job: GoogleJob) do
      queued.publish
    end
  end
end
