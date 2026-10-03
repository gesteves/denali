# Shares a random entry on each of the given networks, on the schedule in config/sidekiq.yml.
#
# Each network gets a job of its own (RandomNetworkShareJob) that picks the entry and enqueues the
# share; this one only decides whether to share at all. That way a failure partway through can't
# be retried into a second share on the networks it had already handled.
class RandomShareJob < ApplicationJob
  # A retry would enqueue every network again, including the ones the failed run already had.
  # Missing one run out of several a day is the better failure, and Bugsnag still hears about it.
  sidekiq_options retry: false

  # @param tags [String, Array<String>] tags the entry must have.
  # @param platforms [Array<String>] the networks to share on (see Entry::SHARE_NETWORKS).
  # @param not_shared_in_months [Integer] how long since the entry was last shared on a network.
  # @param excluded_tags [String, Array<String>] tags the entry mustn't have.
  # @param share_immediately [Boolean] share now, rather than at a random moment in the next hour.
  def perform(tags, platforms, not_shared_in_months = 12, excluded_tags = [], share_immediately = false)
    return if !Rails.env.production?
    # A new photo is out, and its own shares take precedence.
    return if Entry.published.where('published_at > ?', 1.hour.ago).exists?

    Array(platforms).each do |network|
      unless Entry::SHARE_NETWORKS.include?(network)
        logger.warn "[Social] Not sharing on #{network.inspect}, which isn't one of #{Entry::SHARE_NETWORKS.join(', ')}."
        next
      end

      RandomNetworkShareJob.perform_async(network, Array(tags), not_shared_in_months.to_i, Array(excluded_tags), share_immediately)
    end
  end
end
