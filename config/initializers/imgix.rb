::Ix = Imgix::Client.new(hosts: ENV['imgix_domain'].split(','), secure_url_token: ENV['imgix_token'], include_library_param: false, use_https: ENV['imgix_secure'].present?)
