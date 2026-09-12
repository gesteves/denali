namespace :standard_site do
  desc 'Reconcile the standard.site records on the PDS with the entries search engines may index. ' \
       'Run once to seed, and again to recover from a sync that was lost. ' \
       'Needs a running Sidekiq worker to drain the queue. Set DRY_RUN=1 to only report.'
  task :backfill => :environment do
    dry_run = ENV['DRY_RUN'] == 'true' || ENV['DRY_RUN'] == '1'

    blog = Blog.first
    service = StandardSite.from_blog(blog)

    if service.nil?
      puts 'This blog names no Bluesky account for standard.site. Pick one in the blog settings.'
      exit 1
    end

    puts "DRY RUN!\n\n" if dry_run

    result = service.backfill(dry_run: dry_run)

    # The syncs are spaced out to stay inside the PDS write budget, so a big backfill takes hours.
    # Say so, rather than leaving someone watching an empty queue wondering.
    pace = "one every #{result[:spacing].round(1)}s, finishing in about " \
           "#{ActionController::Base.helpers.distance_of_time_in_words(result[:duration])}"

    if dry_run
      puts "Would sync #{result[:synced]} #{'document'.pluralize(result[:synced])} (#{pace})."
      puts "Would prune #{result[:pruned]} #{'record'.pluralize(result[:pruned])} no longer indexable."
    else
      puts "\nSummary:"
      puts "  #{result[:synced]} document sync #{'job'.pluralize(result[:synced])} scheduled: #{pace}"
      puts "  #{result[:pruned]} #{'record'.pluralize(result[:pruned])} pruned"
      puts "\nThey drain on the Sidekiq worker. Leave it running."
    end
  end
end
