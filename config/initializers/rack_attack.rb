class Rack::Attack

  throttle('req/ip', limit: ENV.fetch("IP_THROTTLE_LIMIT") { 100 }.to_i, period: 1.minute) do |req|
    puts "REMOTE IP: #{req.remote_ip}"
    req.remote_ip
  end

  class Request < ::Rack::Request
    def remote_ip
      @remote_ip ||= (env['action_dispatch.remote_ip'] || ip).to_s
    end
  end

end
