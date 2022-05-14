::Ix = Imgix::Client.new(domain: ENV['IMGIX_DOMAIN'], secure_url_token: ENV['IMGIX_TOKEN'], include_library_param: false, use_https: true, api_key: ENV['IMGIX_API_KEY'])
