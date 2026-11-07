# Stops others quoting a new Bluesky post when the blog doesn't allow it (see
# Blog#bluesky_allow_quotes).
class BlueskyPostgateJob < BlueskyGateJob
  private

  def write_gate(bluesky, blog, post_uri)
    bluesky.create_postgate(post_uri) unless blog.bluesky_allow_quotes?
  end
end
