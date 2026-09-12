# Raised when a Bluesky post can never succeed, however many times it is tried: the text is empty
# or too long, or the reply or quote URL doesn't name a post we can read.
#
# BlueskyJob discards it rather than retrying for a day against a post that will never be accepted.
class BlueskyPermanentError < StandardError; end
