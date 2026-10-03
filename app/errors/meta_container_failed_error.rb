# Raised by MetaShareJob when Meta has failed or expired the containers for a share more times
# than it's worth starting over: an image Meta can't fetch or process will keep failing the same
# way. The job discards it, and JobDeathReporter reports it once.
class MetaContainerFailedError < StandardError; end
