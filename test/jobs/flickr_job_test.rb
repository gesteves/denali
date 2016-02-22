require 'test_helper'

class FlickrJobTest < ActiveJob::TestCase
  test 'flickr jobs should be queued if entry published' do
    published = entries(:peppers)
    assert_enqueued_with(job: FlickrJob) do
      published.enqueue_jobs
    end
  end
end
