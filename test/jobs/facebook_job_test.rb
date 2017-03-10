require 'test_helper'

class FacebookJobTest < ActiveJob::TestCase
  test 'facebook jobs should be queued if entry published' do
    queued = entries(:panda)
    assert_enqueued_with(job: FacebookJob) do
      queued.publish
    end
  end
end
