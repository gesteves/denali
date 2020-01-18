class Rack::Attack

  throttle('req/ip', limit: ENV.fetch("IP_THROTTLE_LIMIT") { 100 }.to_i, period: 1.minute) do |req|
    puts "REMOTE IP: #{req.remote_ip}"
    req.remote_ip
  end

  class Request < ::Rack::Request
    def remote_ip
      remote = env['HTTP_X_FORWARDED_FOR'].present? ? env['HTTP_X_FORWARDED_FOR'].split(',')[-2] : nil
      @remote_ip ||= (remote || ip).to_s
    end
  end

end
