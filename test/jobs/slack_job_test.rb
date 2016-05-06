require 'test_helper'

class SlackJobTest < ActiveJob::TestCase
  test 'slack jobs should be queued if entry published' do
    queued = entries(:panda)
    assert_enqueued_with(job: SlackJob) do
      queued.publish
    end
  end
end
