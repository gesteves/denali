namespace :imgix do
  desc "Purges photos from imgix"
  task :purge => :environment do
    Photo.find_each do |photo|
      url = Ix.path(photo.image.key).to_url
      response = HTTParty.post('https://api.imgix.com/v2/image/purger', basic_auth: { username: ENV['imgix_api_key'], password: '' }, body: { url: url })
      puts "#{url}: OK" if response.code.to_i == 200
      puts "#{url}: #{response.body }" if response.code.to_i != 200
      sleep 0.1
    end
  end
end
