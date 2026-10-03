require 'rails_helper'

RSpec.describe 'cache rake tasks', type: :task do
  describe 'cache:purge_pages' do
    it 'queues a purge of every page tag' do
      run_task('cache:purge_pages')
      expect(CachePurgeJob.jobs.map { |job| job['args'] }).to eq([[CacheTags::ENTRIES, CacheTags::BLOG]])
    end
  end
end
