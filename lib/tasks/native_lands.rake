namespace :native_lands do
  desc 'Update native lands for all photos'
  task :update_all => :environment do
    Photo.find_each.with_index do |photo, index|
      NativeLandsJob.perform_in((2 * index).seconds, photo.id)
    end
  end

  desc 'Update native lands for photos without territories'
  task :update_missing => :environment do
    Photo.where.missing(:photo_territories).find_each.with_index do |photo, index|
      NativeLandsJob.perform_in((2 * index).seconds, photo.id)
    end
  end
end
