::Ix = Imgix::Client.new(hosts: ENV['imgix_domain'].split(','), token: ENV['imgix_token'], include_library_param: false)

