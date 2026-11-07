# Limits who can reply to a new Bluesky post (see Blog#bluesky_reply_audience).
class BlueskyThreadgateJob < BlueskyGateJob
  private

  def write_gate(bluesky, blog, post_uri)
    bluesky.create_threadgate(post_uri, audience: blog.bluesky_reply_audience)
  end
end
