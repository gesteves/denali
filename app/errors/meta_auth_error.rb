# Raised when Meta refuses the access token (an OAuthException, code 190): it expired or was
# revoked. Retrying won't help until the account is reconnected in the admin, so the jobs discard
# it and JobDeathReporter reports it once.
class MetaAuthError < StandardError; end
