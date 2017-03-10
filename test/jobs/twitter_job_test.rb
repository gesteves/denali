require 'test_helper'

class TwitterJobTest < ActiveJob::TestCase
  test 'twitter jobs should be queued if entry published' do
    queued = entries(:panda)
    assert_enqueued_with(job: TwitterJob) do
      queued.publish
    end
  end
end
