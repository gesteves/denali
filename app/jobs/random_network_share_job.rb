# Picks a random entry to share on one network and enqueues the share. RandomShareJob enqueues
# one of these for each network on its schedule.
#
# Enqueuing the share is the last thing it does, so a retry can't share twice: anything that fails
# before it leaves nothing shared, and the entry it had picked is reserved and won't be picked
# again.
class RandomNetworkShareJob < ApplicationJob
  sidekiq_options queue: 'high', retry_for: 1.hour.to_i

  SHARE_JOBS = {
    'Bluesky' => BlueskyJob,
    'Mastodon' => MastodonJob,
    'Instagram' => InstagramJob,
    'Threads' => ThreadsJob
  }.freeze

  # How many random entries to try before giving up on this run.
  CANDIDATES = 5

  # How long a picked entry is kept out of later picks. Until its share job records the share,
  # the entry stays among the least shared, so without this the next run could pick it again
  # while the first share was still waiting or retrying. Longer than ShareJob retries for.
  RESERVATION = 7.hours

  # @param network [String] one of Entry::SHARE_NETWORKS.
  # @param tags [Array<String>] tags the entry must have.
  # @param not_shared_in_months [Integer] how long since the entry was last shared on the network.
  # @param excluded_tags [Array<String>] tags the entry mustn't have.
  # @param share_immediately [Boolean] share now, rather than at a random moment in the next hour.
  def perform(network, tags, not_shared_in_months, excluded_tags, share_immediately = false)
    return if !Rails.env.production?

    share_job = SHARE_JOBS.fetch(network)
    pool = Blog.first.entries.eligible_for_random_share(
      platform: network,
      tags: tags,
      excluded_tags: excluded_tags,
      not_shared_in: not_shared_in_months.months
    )
    # Picked by the database: sample would load every eligible entry to keep a few.
    candidates = pool.reorder(Arel.sql('RANDOM()')).limit(CANDIDATES).includes(:user).to_a
    entry = candidates.find { |candidate| shareable?(candidate, network, share_job) }

    if entry.nil?
      logger.info "[Social] Nothing to share on #{network}#{describe(tags, excluded_tags)}: " \
                  "#{pool.count} eligible, and none of the #{candidates.size} tried could go out."
      return
    end

    logger.info "[Social] Sharing \"#{entry.title}\" (#{entry.permalink_url}) on #{network}, " \
                "of #{pool.count} eligible#{describe(tags, excluded_tags)}."
    reserve(network, entry)
    enqueue(share_job, network, entry, share_immediately)
  end

  private

  def shareable?(entry, network, share_job)
    return false if reserved?(network, entry)
    return false unless share_job.available_for?(entry.user)
    return true if entry.valid_caption_for?(network)

    # The stored flags said the caption fit, but a tag or a tag customization has changed since
    # they were set. Bringing them up to date takes the entry out of the pool until it's fixed.
    entry.update_caption_validity
    false
  end

  def reservation_key(network, entry)
    "random-share/#{network.downcase}/#{entry.id}"
  end

  def reserved?(network, entry)
    Rails.cache.exist?(reservation_key(network, entry))
  end

  def reserve(network, entry)
    Rails.cache.write(reservation_key(network, entry), true, expires_in: RESERVATION)
  end

  # Enqueues the share with the caption that was just checked, so what goes out is what fit.
  def enqueue(share_job, network, entry, share_immediately)
    caption = entry.caption_for(network)
    delay = share_immediately ? nil : rand(0..60).minutes
    args = [entry.id, caption]
    # Bluesky needs its record key up front, so a retry replaces the post instead of adding
    # another. The key is also the feed's sort key, so a delayed share takes the key of the moment
    # it will actually go out; otherwise it would sort at the moment it was queued, up to an hour
    # earlier.
    args += [nil, nil, delay ? Bluesky.new_tid(at: delay.from_now) : Bluesky.new_tid] if network == 'Bluesky'

    delay ? share_job.perform_in(delay, *args) : share_job.perform_async(*args)
  end

  def describe(tags, excluded_tags)
    description = ''
    description += " tagged #{tags.join(', ')}" if tags.any?
    description += " excluding #{excluded_tags.join(', ')}" if excluded_tags.any?
    description
  end
end
