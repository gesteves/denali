namespace :imgix do
  desc "Purges photos from imgix"
  task :purge => :environment do
    if ENV['ENTRY_ID'].present?
      entry = Entry.find(ENV['ENTRY_ID'])
      purge_imgix(entry)
    elsif ENV['OLDEST_ENTRY_ID'].present?
      entries = Entry.where('id >= ?', ENV['OLDEST_ENTRY_ID']).order('id DESC')
      entries.each do |e|
        purge_imgix(e)
      end
    end
  end
end

def purge_imgix(entry)
  puts "Purging photos for entry #{entry.id} (#{entry.title})"
  entry.photos.each do |p|
    url = Ix.path(p.original_path).to_url
    response = HTTParty.post('https://api.imgix.com/v2/image/purger', basic_auth: { username: ENV['imgix_api_key'], password: '' }, body: { url: url })
    puts response.body if response.code.to_i != 200
  end
end
