::Ix = Imgix::Client.new(
  domain: ENV['imgix_domain'],
  secure_url_token: ENV['imgix_token'],
  include_library_param: false,
  use_https: ENV['imgix_secure'].present?
)
