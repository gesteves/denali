namespace :entry do
  task :modified_at => [:environment] do
    Entry.published.find_each do |e|
      puts "Setting modified_at date for entry ##{e.id} to #{e.published_at}"
      e.modified_at = e.published_at
      e.save
    end
  end
end
