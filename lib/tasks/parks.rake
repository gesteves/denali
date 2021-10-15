namespace :parks do
  desc 'Populates a list of National Park Units in redis'
  task :populate => :environment do
    next unless ENV['nps_api_key'].present?

    url = "https://developer.nps.gov/api/v1/parks?limit=1000&api_key=#{ENV['nps_api_key']}"
    response = HTTParty.get(url)
    next if response.code >= 400

    $redis.del('parks')
    parks = JSON.parse(response.body)['data'].map { |p| p['fullName'] }
    parks.each do |p|
      puts "Adding #{p} to redis"
      $redis.sadd('parks', p.parameterize)
    end
  end
end
