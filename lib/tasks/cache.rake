namespace :cache do
  # Run after a deploy (see .github/workflows/ci.yml). Cached pages name the
  # previous deploy's fingerprinted CSS and JS, which the new image doesn't have,
  # so they'd load unstyled until the edge copy expired.
  desc 'Purge every cached page at Cloudflare'
  task purge_pages: :environment do
    CachePurgeJob.perform_async(CacheTags::ENTRIES, CacheTags::BLOG)
    puts "Queued a purge of #{CacheTags::ENTRIES} and #{CacheTags::BLOG}."
  end
end
