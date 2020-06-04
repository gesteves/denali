::Ix = Imgix::Client.new(host: ENV['imgix_domain'], secure_url_token: ENV['imgix_token'], include_library_param: false, use_https: true, api_key: ENV['imgix_api_key'])
