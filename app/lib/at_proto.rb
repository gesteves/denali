require 'mini_magick'

# The AT Protocol plumbing every PDS client in this app shares: the session, the record writes, the
# record reads, and the image blobs.
#
# Bluesky and StandardSite talk to the *same* PDS with the *same* credentials, so the session
# belongs in one place. Two copies would need two edits whenever the account, the endpoint or the
# authentication changed, and the copy someone forgot would only fail at the next publish.
#
# An includer has to call #configure_at_proto from its own initializer, and define #at_proto_label,
# which names it in error messages.
module AtProto
  extend ActiveSupport::Concern

  # The "sortable base32" alphabet of a record key.
  # @see https://atproto.com/specs/tid
  TID_ALPHABET = "234567abcdefghijklmnopqrstuvwxyz".freeze

  # .new_tid has to return a value that rises on every call, and more than one thread can ask.
  TID_LOCK = Mutex.new

  # How many scheduled moments to remember, so the table can't grow for the life of the process.
  # One entry per distinct minute someone schedules for, and a handful is plenty.
  SCHEDULED_TID_MEMORY = 64

  # Every request here gets a timeout. Admin::EntriesController runs a share inline, inside the web
  # request, so a PDS that hangs would otherwise hang Rails; in a job it would hold a Sidekiq
  # thread until the process was killed.
  SESSION_TIMEOUT = 10
  RESOLVE_TIMEOUT = 5
  REQUEST_TIMEOUT = 15
  UPLOAD_TIMEOUT = 30
  IMAGE_TIMEOUT = 15

  # The most we will read from the photo CDN before giving up. These are our own URLs, but a body
  # of unbounded size read into a Sidekiq thread is still a way to lose the process.
  MAX_SOURCE_IMAGE_BYTES = 20 * 1024 * 1024

  # Cloudflare has no equivalent to Thumbor's old max_bytes filter, so a transformed JPEG can still
  # come back over whatever limit the lexicon sets. When it does, walk it down these steps —
  # dropping JPEG quality first, then scaling the image — and take the first result that fits.
  # Without this, an oversized photo produces the same too-big blob on every retry.
  BLOB_COMPRESSION_STEPS = [
    { quality: 70 },
    { quality: 60 },
    { quality: 50 },
    { quality: 40, resize: '85%' },
    { quality: 40, resize: '70%' },
    { quality: 40, resize: '55%' }
  ].freeze

  # How many pages of records to read. A PDS that answers with the same cursor forever, or a cursor
  # that never ends, must not make this loop for the life of a backfill.
  MAX_LIST_PAGES = 200

  # The PDS rejected our token. The caller clears the cached session and tries once more.
  class UnauthorizedError < StandardError; end

  # The PDS refused the handle and app password outright.
  class AuthenticationError < StandardError; end

  # The PDS could not be reached at all.
  class ConnectionError < StandardError; end

  # The PDS is refusing writes for now. It carries the moment it will accept them again, so a job
  # can wait exactly that long instead of guessing.
  class RateLimitedError < StandardError
    # @return [Integer] seconds to wait before trying again.
    attr_reader :retry_after

    def initialize(message, retry_after:)
      @retry_after = retry_after
      super(message)
    end
  end

  # A PDS budgets writes in points, per account: 3 for a create, 2 for an update, 1 for a delete,
  # against 5,000 an hour and 35,000 a day. That is at most 1,666 records written an hour.
  #
  # ⚠️ A bulk reconciliation has to be spread out to stay under it. Sidekiq runs this app's jobs ten
  # at a time, so an unthrottled backfill of a few hundred entries hits the ceiling within minutes,
  # and every job past it gets a 429.
  # @see https://docs.bsky.app/docs/advanced-guides/rate-limits
  WRITE_POINTS_PER_HOUR = 5_000
  # What one putRecord costs. It's 2 for a record that already exists, but budget for the worse of
  # the two, because a backfill of a repo that is empty is all creates.
  WRITE_POINTS_PER_RECORD = 3
  # Leave room for the posts and the threadgates the app writes while a backfill is draining.
  WRITE_BUDGET_FRACTION = 0.5

  # How long to leave between two record writes to stay inside the budget.
  #
  # @return [Float] seconds.
  def self.seconds_between_writes
    writes_per_hour = (WRITE_POINTS_PER_HOUR / WRITE_POINTS_PER_RECORD) * WRITE_BUDGET_FRACTION
    3600.0 / writes_per_hour
  end

  # What "could not reach the PDS" actually looks like.
  CONNECTION_ERRORS = [
    SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ENETUNREACH,
    Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError, HTTParty::Error, JSON::ParserError,
    Timeout::Error
  ].freeze

  class_methods do
    # Makes a record key for a new record.
    #
    # The caller makes this *before* it enqueues the job, and the job writes with putRecord. A
    # second attempt then replaces the same record instead of adding a second one — createRecord
    # mints its own key each time, so every retry there is another record.
    #
    # The shape is a TID: a zero bit, 53 bits of microseconds, and 10 bits of a random clock id, so
    # a later record sorts after an earlier one, which is what a feed needs.
    #
    # @param at [Time, nil] the moment the record should sort at. Nil means now.
    # @return [String] a 13-character TID.
    def new_tid(at: nil)
      # A scheduled share has to sort at the moment it goes out, not the moment it was queued: a
      # post scheduled for tomorrow would otherwise carry today's key and land below a day of newer
      # posts.
      #
      # ⚠️ It needs a counter of its own, and it must not touch the one below. The admin's schedule
      # field is minute-granular, so two posts scheduled for the same minute get identical
      # microseconds and differ only in the 10 random bits — a 1-in-1024 chance of the same key.
      # With putRecord that is not an error, it is one post silently replacing the other. And a
      # future-dated schedule must not be allowed to push every immediate key after it forward.
      if at.present?
        return TID_LOCK.synchronize do
          # The admin's schedule field is minute-granular, so the microseconds inside that minute
          # are all free. Counting up through them keeps two posts scheduled for the same minute
          # apart and still sorts them in the order they were made.
          #
          # ⚠️ The count is per moment, never global: a single counter would push a post scheduled
          # for tomorrow past one already scheduled for next month, giving it that month's key and
          # createdAt.
          base = tid_micros(at)
          bump = (@scheduled_tid_bumps ||= {}).delete(base).to_i
          @scheduled_tid_bumps[base] = bump + 1
          @scheduled_tid_bumps.shift while @scheduled_tid_bumps.size > SCHEDULED_TID_MEMORY

          encode_tid(((base + bump) << 10) | SecureRandom.random_number(1 << 10))
        end
      end

      # The clock alone is not monotonic, and a caller can ask for several keys inside one
      # microsecond. The low bits are random, so without this the keys of a thread would sort in a
      # random order and a reply could come out above its own root.
      TID_LOCK.synchronize do
        micros = tid_micros(Time.now)
        @last_tid_micros = @last_tid_micros.to_i >= micros ? @last_tid_micros + 1 : micros
        encode_tid((@last_tid_micros << 10) | SecureRandom.random_number(1 << 10))
      end
    end

    # Encodes a 64-bit value as a 13-character TID.
    #
    # @param value [Integer] the value to encode.
    # @return [String] the TID.
    def encode_tid(value)
      encoded = +""
      while value.positive?
        encoded = TID_ALPHABET[value % 32] + encoded
        value /= 32
      end
      encoded.rjust(13, TID_ALPHABET[0])
    end

    # Reads the time back out of a TID that .new_tid made.
    #
    # 13 characters of base32 hold 65 bits and a TID holds 64 with its high bit zero, so the value
    # is below 2**63 and the first character is one of the first EIGHT of the alphabet. A string
    # of 13 alphabet characters that fails that is not a TID at all.
    #
    # ⚠️ It does NOT tell a time-ordered key from a content-addressed one. StandardSite.tid masks
    # its digest to the low 63 bits, so its high bit is zero too and it decodes here to a Time that
    # means nothing — measured, not assumed. Nothing calls .record_timestamp with a standard.site
    # key today; don't start, because no check here could catch it.
    #
    # @param tid [String] a 13-character TID.
    # @return [Time, nil] the time, or nil for a value of another shape.
    def tid_time(tid)
      return unless tid.to_s.match?(/\A[#{TID_ALPHABET[0, 8]}][#{TID_ALPHABET}]{12}\z/)

      value = tid.each_char.reduce(0) { |acc, char| (acc * 32) + TID_ALPHABET.index(char) }
      Time.at(Rational(value >> 10, 1_000_000)).utc
    end

    # The createdAt a record carries.
    #
    # It comes from the record key, so every attempt of a job writes byte-identical bytes and the
    # CID doesn't change. A new CID would leave a published reply's parent pointing at a version
    # that is gone.
    #
    # Milliseconds matter on their own: two posts of a thread go out inside the same second, and
    # the AppView sorts an author feed by this value. With whole seconds a root could sort below
    # its own reply and disappear from the Posts tab while the reply stayed.
    #
    # @param rkey [String] the record key.
    # @return [String] an ISO 8601 timestamp in UTC, to the millisecond.
    def record_timestamp(rkey)
      (tid_time(rkey) || Time.now).utc.iso8601(3)
    end

    # @param time [Time] the moment to encode.
    # @return [Integer] its microseconds, in the 53 bits a TID holds.
    def tid_micros(time)
      (time.to_r * 1_000_000).to_i & ((1 << 53) - 1)
    end
    private :tid_micros
  end

  private

  # Stores the PDS and the credentials. An includer calls this from its own initializer.
  #
  # @param base_url [String] the base URL of the PDS.
  # @param identifier [String] the handle or email of the account.
  # @param password [String] the app password.
  # @return [void]
  def configure_at_proto(base_url:, identifier:, password:)
    @base_url = base_url.to_s.chomp('/')
    @auth = { identifier: identifier, password: password }
  end

  # Writes or replaces a record. The repo, the collection and the rkey identify it, so this can be
  # done more than once and still leave one record.
  #
  # @param collection [String] the lexicon id.
  # @param rkey [String] the record key.
  # @param record [Hash] the record data.
  # @param validate [Boolean, nil] false where the PDS doesn't know the lexicon. Nil omits it.
  # @return [Hash] the parsed response body, holding the record's uri and cid.
  # @raise [RuntimeError] if the write fails.
  def put_record(collection:, rkey:, record:, validate: nil)
    with_valid_session do
      body = { repo: did, collection: collection, rkey: rkey, record: record }
      body[:validate] = validate unless validate.nil?

      response = HTTParty.post("#{@base_url}/xrpc/com.atproto.repo.putRecord",
                               body: body.to_json,
                               headers: auth_headers,
                               timeout: REQUEST_TIMEOUT)

      raise UnauthorizedError, "#{at_proto_label} rejected the access token" if response.code == 401
      raise_if_rate_limited(response, "writing #{collection}/#{rkey}")
      raise "Failed to write #{collection} record: #{response.body}" unless response.success?

      written = JSON.parse(response.body)
      # A reply names its parent by uri *and* cid, so a response with no cid would make the next
      # post of a thread invalid, with a message naming that post rather than this one.
      raise "#{at_proto_label} wrote #{collection}/#{rkey} but returned no cid" if written["cid"].blank?

      written
    end
  end

  # Removes a record. A record that isn't there is not an error, so this can be done more than once.
  #
  # It answers with a boolean rather than raising, because the prune step of a backfill calls it for
  # every record that is no longer current and one unreachable record must not stop a whole
  # reconciliation run. A caller that wants a retry raises on false itself.
  #
  # @param collection [String] the lexicon id.
  # @param rkey [String] the record key.
  # @return [Boolean] whether it succeeded.
  def delete_record(collection:, rkey:)
    with_valid_session do
      response = HTTParty.post("#{@base_url}/xrpc/com.atproto.repo.deleteRecord",
                               body: { repo: did, collection: collection, rkey: rkey }.to_json,
                               headers: auth_headers,
                               timeout: REQUEST_TIMEOUT)

      raise UnauthorizedError, "#{at_proto_label} rejected the access token" if response.code == 401
      # ⚠️ Raised, not swallowed. A 429 means "come back later", and reporting it as a failed delete
      # would leave the caller thinking the record is still there for a reason that won't change.
      raise_if_rate_limited(response, "deleting #{collection}/#{rkey}")

      unless response.success?
        Rails.logger.warn("#{at_proto_label}: failed to delete #{collection}/#{rkey} (HTTP #{response.code}: #{response.body})")
        next false
      end

      true
    end
  rescue UnauthorizedError, *CONNECTION_ERRORS => e
    Rails.logger.warn("#{at_proto_label}: error deleting #{collection}/#{rkey}: #{e.message}")
    false
  end

  # Every record key in a collection of this repo.
  #
  # @param collection [String] the collection to list.
  # @return [Array<String>] the record keys, a page at a time through the cursor.
  def list_record_rkeys(collection:)
    rkeys = []
    cursor = nil

    MAX_LIST_PAGES.times do
      body = list_records_page(collection, cursor)
      break if body.nil?

      records = Array(body["records"])
      # compact_blank: a row with no uri yields "", and the prune would then ask the PDS to delete
      # a record key with no characters in it.
      rkeys.concat(records.map { |record| record["uri"].to_s.split("/").last }.compact_blank)
      next_cursor = body["cursor"]
      break if next_cursor.blank? || records.empty? || next_cursor == cursor

      cursor = next_cursor
    end

    rkeys
  end

  # One page of #list_record_rkeys.
  #
  # @return [Hash, nil] the parsed body, or nil if the page couldn't be read.
  def list_records_page(collection, cursor)
    with_valid_session do
      query = { repo: did, collection: collection, limit: 100 }
      query[:cursor] = cursor if cursor.present?

      response = HTTParty.get("#{@base_url}/xrpc/com.atproto.repo.listRecords",
                              query: query, headers: auth_headers, timeout: REQUEST_TIMEOUT)

      raise UnauthorizedError, "#{at_proto_label} rejected the access token" if response.code == 401
      next nil unless response.success?

      JSON.parse(response.body)
    end
  rescue UnauthorizedError, *CONNECTION_ERRORS => e
    Rails.logger.warn("#{at_proto_label}: error listing #{collection}: #{e.message}")
    nil
  end

  # Reads one record of this repo.
  #
  # @param collection [String] the lexicon id.
  # @param rkey [String] the record key.
  # @return [Hash, nil] the record's value, or nil if it's absent or can't be read.
  def get_own_record(collection:, rkey:)
    with_valid_session do
      response = HTTParty.get("#{@base_url}/xrpc/com.atproto.repo.getRecord",
                              query: { repo: did, collection: collection, rkey: rkey },
                              headers: auth_headers, timeout: REQUEST_TIMEOUT)

      raise UnauthorizedError, "#{at_proto_label} rejected the access token" if response.code == 401
      next nil unless response.success?

      JSON.parse(response.body)["value"]
    end
  rescue UnauthorizedError, *CONNECTION_ERRORS, JSON::ParserError
    nil
  end

  # Uploads raw bytes to the PDS as a blob.
  #
  # @param data [String] the binary data.
  # @param content_type [String] its content type.
  # @return [Hash] the parsed response body from the upload.
  # @raise [RuntimeError] if the upload fails.
  def upload_blob(data, content_type)
    with_valid_session do
      response = HTTParty.post("#{@base_url}/xrpc/com.atproto.repo.uploadBlob",
                               body: data,
                               headers: { "Authorization" => "Bearer #{access_token}",
                                          "Content-Type" => content_type },
                               timeout: UPLOAD_TIMEOUT)

      raise UnauthorizedError, "#{at_proto_label} rejected the access token" if response.code == 401
      raise_if_rate_limited(response, 'uploading a blob')
      raise "Failed to upload blob: #{response.body}" unless response.success?

      JSON.parse(response.body)
    end
  end

  # Turns a 429 into an error that carries how long to wait.
  #
  # The PDS sends `ratelimit-reset` as a unix timestamp. Using it means a job waits exactly as long
  # as it has to, rather than burning retries against a limit that hasn't lifted yet.
  #
  # @param response [HTTParty::Response] the response.
  # @param doing [String] what we were doing, for the message.
  # @return [void]
  # @raise [RateLimitedError] if the PDS answered 429.
  def raise_if_rate_limited(response, doing)
    return unless response.code == 429

    reset = response.headers['ratelimit-reset'].to_i
    wait = reset.positive? ? (Time.at(reset) - Time.now).ceil : 0
    # A minute at least, an hour at most: a header that is missing, in the past, or absurd must
    # still give a sane delay.
    wait = wait.clamp(60, 3600)

    raise RateLimitedError.new("#{at_proto_label} is rate limiting us #{doing}; waiting #{wait}s", retry_after: wait)
  end

  # @return [Hash] the JSON request headers with the bearer token.
  def auth_headers
    { "Authorization" => "Bearer #{access_token}", "Content-Type" => "application/json" }
  end

  # The cache key for the account's DID.
  #
  # @return [String] the cache key.
  def did_key
    "bluesky:#{@auth[:identifier]}:did"
  end

  # The cache key for the account's access token.
  #
  # @return [String] the cache key.
  def access_token_key
    "bluesky:#{@auth[:identifier]}:access_token"
  end

  # The access token, from the cache or from a new session.
  #
  # Memoizing on the instance is what keeps a cold cache down to a single createSession: the first
  # call writes both cache keys, and everything after it reads them.
  #
  # @return [String] the access token.
  def access_token
    @access_token ||= Rails.cache.read(access_token_key) || create_session["accessJwt"]
  end

  # The account's DID, from the cache or from a new session.
  #
  # @return [String] the DID.
  def did
    @did ||= Rails.cache.read(did_key) || create_session["did"]
  end

  # Runs a request that needs the access token, and runs it once more with a fresh session if the
  # PDS says the token is no good.
  #
  # A token can stop working before its cache entry expires — it can be revoked, or the app
  # password can be changed. Without this, every attempt for the rest of the hour fails against
  # the same dead token, which is long enough to exhaust a job's retries.
  #
  # @yield the request to run.
  # @return [Object] whatever the block returns.
  def with_valid_session
    yield
  rescue UnauthorizedError
    reset_session!
    yield
  end

  # Forgets the cached session so the next request authenticates again.
  #
  # @return [void]
  def reset_session!
    Rails.cache.delete(access_token_key)
    Rails.cache.delete(did_key)
    @access_token = nil
    @did = nil
  end

  # Opens a new session with the PDS and caches the DID and access token.
  #
  # ⚠️ Don't give an includer a method of this name. A wrapper that calls back into the session
  # would be dispatched here, and the pair would recurse until the stack ran out — which is exactly
  # what happened in the sibling app.
  #
  # @return [Hash] the parsed session response.
  # @raise [AuthenticationError] if the PDS refuses the handle and app password.
  # @raise [ConnectionError] if the PDS can't be reached.
  def create_session
    body = { identifier: @auth[:identifier], password: @auth[:password] }

    response = HTTParty.post("#{@base_url}/xrpc/com.atproto.server.createSession",
                             body: body.to_json,
                             headers: { "Content-Type" => "application/json" },
                             timeout: SESSION_TIMEOUT)

    # A 400 or a 401 is the PDS refusing these credentials, and no number of retries will change
    # that. Anything else — a 5xx, a 429 — means the PDS is having a bad day and it is worth
    # trying again.
    if [400, 401].include?(response.code)
      raise AuthenticationError, "#{at_proto_label} refused the credentials: #{response.code} #{response.body}"
    end
    unless response.success?
      raise ConnectionError, "The #{at_proto_label} PDS answered #{response.code}: #{response.body}"
    end

    session = JSON.parse(response.body)
    Rails.cache.write(did_key, session["did"])
    Rails.cache.write(access_token_key, session["accessJwt"], expires_in: 1.hour)
    @did = session["did"]
    @access_token = session["accessJwt"]
    session
  # Only the errors that really mean "the network or the PDS misbehaved" become a ConnectionError.
  # Catching StandardError here would turn a NoMethodError in the parsing below into "check the
  # server URL", and into a job that retries a code bug all day.
  rescue *CONNECTION_ERRORS => e
    raise ConnectionError, "Could not reach the #{at_proto_label} PDS at #{@base_url}: #{e.message}"
  end

  # Downloads an image, stopping if the body runs past MAX_SOURCE_IMAGE_BYTES.
  #
  # The content type is checked because a 200 that is really an HTML error page would otherwise be
  # uploaded as a blob and fail later, against the record rather than the image.
  #
  # @param url [String] the URL of the image.
  # @return [Array(String, String)] the image data and its content type.
  # @raise [RuntimeError] if the fetch fails, the body is not an image, or it is too large.
  def fetch_image(url)
    body = String.new(encoding: Encoding::BINARY)
    content_type = nil
    response = nil

    # Read in fragments and stop at the limit, rather than letting an unbounded body into a
    # Sidekiq thread. Throwing leaves `response` nil, which is how the check below tells "too
    # large" from "the fetch failed".
    catch(:too_big) do
      response = HTTParty.get(url, stream_body: true, timeout: IMAGE_TIMEOUT) do |fragment|
        next unless (200..299).cover?(fragment.code.to_i)

        content_type ||= fragment.http_response['content-type'].to_s
        body << fragment.to_s.b
        throw :too_big if body.bytesize > MAX_SOURCE_IMAGE_BYTES
      end
    end

    if body.bytesize > MAX_SOURCE_IMAGE_BYTES
      raise "Image at #{url} is over the #{MAX_SOURCE_IMAGE_BYTES} byte limit"
    end
    raise "Failed to fetch image from #{url}: #{response&.code}" unless response&.success?
    # An empty 200 would go up as a zero-byte blob and fail against the record instead of the image.
    raise "Image at #{url} came back empty" if body.empty?

    content_type = content_type.to_s.split(';').first.to_s.strip
    unless content_type.start_with?('image/')
      raise "Expected an image from #{url}, got #{content_type.presence || 'no content type'}"
    end

    [body, content_type]
  end

  # Recompresses an oversized image so its blob fits under a limit, returning JPEG data.
  #
  # Walks through BLOB_COMPRESSION_STEPS and returns the first attempt at or under the target; if
  # none fit, returns the smallest (last) attempt, which is still far smaller than the original.
  #
  # @param image_data [String] the raw (binary) image data to compress.
  # @param target [Integer] the byte size to come in under.
  # @return [String] the recompressed JPEG data.
  def compress_under_blob_limit(image_data, target:)
    candidate = image_data
    BLOB_COMPRESSION_STEPS.each do |step|
      candidate = recompress_image(image_data, **step)
      return candidate if candidate.bytesize <= target
    end
    candidate
  end

  # Recompresses an image as a JPEG at the given quality, optionally scaling it down first.
  #
  # @param image_data [String] the raw (binary) image data to recompress.
  # @param quality [Integer] the JPEG quality to encode at.
  # @param resize [String, nil] an optional ImageMagick geometry (e.g. '70%') to scale by.
  # @return [String] the recompressed JPEG data.
  def recompress_image(image_data, quality:, resize: nil)
    image = MiniMagick::Image.read(image_data)
    image.format('jpeg')
    image.combine_options do |img|
      img.resize(resize) if resize
      img.quality(quality.to_s)
      img.strip
    end
    image.to_blob
  end

  # Cuts a string to a number of grapheme clusters. Every text field of a record is limited in
  # graphemes, and String#length counts UTF-16 code units.
  #
  # @param str [String, nil] the string to cut.
  # @param max [Integer] the most graphemes to keep.
  # @return [String, nil] the string, made shorter if it needed to be.
  def truncate_graphemes(str, max)
    return str if str.blank?

    graphemes = str.scan(/\X/)
    graphemes.length > max ? graphemes.first(max).join : str
  end
end
