require 'test_helper'

class FlickrJobTest < ActiveJob::TestCase
  test 'flickr jobs should be queued if entry published' do
    queued = entries(:panda)
    assert_enqueued_with(job: FlickrJob) do
      queued.publish
    end
  end
end
