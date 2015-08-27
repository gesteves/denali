::Images = Imgix::Client.new(host: ENV['imgix_domain'], token: ENV['imgix_token'], include_library_param: false)
