require 'test_helper'

class TumblrJobTest < ActiveJob::TestCase
  test 'tumblr jobs should be queued if entry published' do
    queued = entries(:panda)
    assert_enqueued_with(job: TumblrJob) do
      queued.publish
    end
  end
end
