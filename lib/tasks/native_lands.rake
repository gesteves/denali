namespace :native_lands do
  desc 'Update native lands for all photos'
  task :update_all => :environment do
    Photo.find_each.with_index do |photo, index|
      NativeLandsWorker.perform_in((2 * index).seconds, photo.id)
    end
  end
end
