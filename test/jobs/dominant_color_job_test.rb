require 'test_helper'

class DominantColorJobTest < ActiveJob::TestCase
  test 'color job should be queued if photo saved' do
    photo = photos(:peppers)
    assert_nil photo.dominant_color
    assert_enqueued_with(job: DominantColorJob) do
      photo.get_dominant_color
    end
  end
end
