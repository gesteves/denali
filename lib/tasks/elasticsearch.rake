require 'elasticsearch/rails/tasks/import'

namespace :elasticsearch do
  namespace :update do
    desc "Updates entry index with new settings and mappings"
    task :entry => :environment do
      puts "Deleting existing index..."
      Entry.__elasticsearch__.delete_index! rescue nil

      puts "Creating index with new settings..."
      Entry.__elasticsearch__.create_index!

      puts "Importing entries (this may take a few minutes)..."
      Entry.import(force: true, batch_size: 100)

      puts "\nDone! Index has been updated."
    end
  end
end
