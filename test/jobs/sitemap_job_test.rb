require 'test_helper'

class SitemapJobTest < ActiveJob::TestCase
  test 'sitemap jobs should be queued if entry published' do
    queued = entries(:panda)
    assert_enqueued_with(job: SitemapJob) do
      queued.publish
    end
  end
end
