namespace :native_lands do
  desc 'Update native lands for all photos'
  task :update_all => :environment do
    Photo.find_each do |photo|
      photo.update_native_lands
    end
  end
end
