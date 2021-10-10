namespace :google_vision do
  desc 'Annotate all photos with Google Vision'
  task :annotate_all => :environment do
    Photo.find_each do |photo|
      photo.annotate
    end
  end
end
