namespace :tumblr do
  desc "Adds Tumblr IDs"
  task :update => :environment do
    puts "Updating Tumblr IDs"
    table = CSV.parse(File.read(Rails.root.join('tumblr_ids.csv')), headers: true)
    table.each do |row|
      entry = Entry.published.where(id: row['id']).first
      next if entry.blank? || row['tumblr_id'].blank?
      puts "Adding Tumblr ID #{row['tumblr_id']} to entry #{entry.id}: #{entry.permalink_url}"
      entry.tumblr_id = row['tumblr_id'].to_s
      entry.save!
    end
  end
end
