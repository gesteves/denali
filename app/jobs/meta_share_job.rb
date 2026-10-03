# What posting to Instagram and Threads has in common. Both make a post in steps: create a
# container for each photo (and for a carousel, one more that holds them), wait while Meta fetches
# and processes the images, then publish.
#
# ⚠️ The steps are spread across attempts of the job rather than run in one go.
#
# - Waiting used to mean sleeping in the job, holding one of Sidekiq's few threads for as long as
#   Meta took: at least five seconds a container, one after another for a carousel's photos. Now an
#   attempt that finds Meta still processing raises MetaContainerPendingError, and retry_delay
#   brings the job back a few seconds later.
# - What each attempt made is kept between attempts, keyed by the job's jid (which Sidekiq's
#   retries keep), so a retry carries on where the last attempt stopped. It used to make new
#   containers, so an attempt that failed after publishing posted the photo a second time.
class MetaShareJob < ShareJob
  # How long a share's progress is kept: longer than ShareJob retries for.
  STATE_TTL = 1.day

  # How many times to start over with new containers after Meta fails or expires them. An image
  # Meta can't fetch or process fails the same way every time.
  MAX_RESTARTS = 2

  # How long to wait before checking on a container again.
  PENDING_DELAY = 10

  def self.retry_delay(count, exception)
    case exception
    when MetaContainerPendingError
      PENDING_DELAY
    when MetaCaptionTooLongError, MetaAuthError, MetaContainerFailedError
      # A caption over the limit, a token Meta refuses, or an image it can't process: none of them
      # get better by trying again for six hours. JobDeathReporter reports them once.
      :discard
    else
      super
    end
  end

  # @param entry_id [Integer]
  # @param text [String, nil] the caption. Without one, the job builds the entry's caption when
  #   it runs rather than when it was enqueued, so an entry published straight from the form gets
  #   the tags and EXIF details that are only filled in after it's saved.
  def perform(entry_id, text = nil)
    entry = shareable_entry(entry_id)
    return if entry.nil? || !self.class.available_for?(entry.user)

    @state = read_state
    text ||= entry.caption_for(network)
    # Checked here, before anything is made at Meta, rather than found out from the API after
    # every photo's container.
    limit = Entry::CAPTION_LIMITS.fetch(network)
    raise MetaCaptionTooLongError, "#{network} caption is #{text.length} characters, over #{limit}" if text.length > limit

    client = build_client(entry.user)
    publish_when_ready(client, entry, text) unless @state['published']
    finish(entry)
  end

  private

  # @return [String] the network's name, as Entry::SHARE_NETWORKS has it.
  def network
    raise NotImplementedError
  end

  # @return [Instagram, Threads]
  def build_client(user)
    raise NotImplementedError
  end

  # @return [String] the photo's URL for this network.
  def photo_url(photo)
    raise NotImplementedError
  end

  # @return [String] the container ID of a post with a single photo.
  def create_single_container(client, entry, photo, text)
    raise NotImplementedError
  end

  # @return [String] the container ID of a carousel holding the given containers.
  def create_carousel_container(client, entry, children, text)
    raise NotImplementedError
  end

  # What follows a published post, such as Instagram's hashtag comment. It runs on every attempt
  # after publishing, so it must be safe to repeat.
  def after_publish(entry, media_id); end

  def publish_when_ready(client, entry, text)
    if @state['container']
      status = client.container_status(@state['container'])
      case status['code']
      when 'FINISHED'
        return mark_published(client.publish_container(@state['container'])['id'])
      when 'PUBLISHED'
        # Published by an earlier attempt whose response never arrived.
        return mark_published(nil)
      when 'IN_PROGRESS'
        raise MetaContainerPendingError, "#{network} is still processing container #{@state['container']}"
      else
        start_over(status)
      end
    end

    if @state['children']
      statuses = @state['children'].map { |child| client.container_status(child) }
      failed = statuses.find { |status| %w[FINISHED IN_PROGRESS].exclude?(status['code']) }
      if failed
        start_over(failed)
      elsif statuses.all? { |status| status['code'] == 'FINISHED' }
        save_state('container' => create_carousel_container(client, entry, @state['children'], text))
        raise MetaContainerPendingError, "#{network} is processing carousel container #{@state['container']}"
      else
        raise MetaContainerPendingError, "#{network} is still processing a carousel's photos"
      end
    end

    create_containers(client, entry, text)
  end

  def create_containers(client, entry, text)
    photos = entry.photos.limit(self.class::MAX_PHOTOS).to_a
    # Meta fetches the images itself, and gives up on a slow fetch; a cached copy is a fast one.
    photos.each { |photo| photo.warm_cache(photo_url(photo)) }

    if photos.size == 1
      save_state('container' => create_single_container(client, entry, photos.first, text))
    else
      items = photos.map { |photo| { url: photo_url(photo), alt_text: photo.alt_text } }
      save_state('children' => client.create_carousel_items(items))
    end
    raise MetaContainerPendingError, "#{network} is processing the new containers"
  end

  # Drops a failed or expired container and what it held, so the next attempt makes new ones.
  def start_over(status)
    restarts = @state['restarts'].to_i + 1
    if restarts > MAX_RESTARTS
      raise MetaContainerFailedError, "#{network} container ended #{status['code']} after #{MAX_RESTARTS} fresh starts: #{status['error']}"
    end

    logger.warn "[#{network}] Container ended #{status['code']} (#{status['error']}); starting over"
    @state = { 'restarts' => restarts }
    write_state
  end

  def mark_published(media_id)
    save_state('published' => true, 'media_id' => media_id)
  end

  def finish(entry)
    unless @state['recorded']
      record_share(entry, network.downcase)
      save_state('recorded' => true)
    end
    after_publish(entry, @state['media_id'])
  end

  # Where this job's progress is kept. A job run outside Sidekiq has no jid, and keeps nothing.
  def state_key
    "meta-share/#{self.class.name.underscore}/#{jid}" if jid.present?
  end

  def read_state
    (state_key && Rails.cache.read(state_key)) || {}
  end

  def save_state(changes)
    @state = @state.merge(changes)
    write_state
  end

  def write_state
    return unless state_key
    # Without its progress, the next attempt would make new containers again, every few seconds.
    # Failing like any other error backs off instead, and Bugsnag hears that the cache is down.
    return if Rails.cache.write(state_key, @state, expires_in: STATE_TTL)

    raise "Couldn't keep #{network} share progress in the cache"
  end
end
