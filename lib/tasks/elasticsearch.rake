require 'elasticsearch/rails/tasks/import'

namespace :elasticsearch do
  namespace :update do
    desc "Updates entry index"
    task :entry => :environment do
      Entry.__elasticsearch__.create_index! force: true
      Entry.__elasticsearch__.import
    end
  end
end
