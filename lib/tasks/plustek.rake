namespace :plustek do
  task :remove => :environment do
    lens = Lens.find_by!(display_name: 'Nikkor 50mm f/1.4 AI')
    camera = Camera.find_by!(display_name: 'Nikon FE')
    ids = ENV['ENTRY_IDS'].split(',').map(&:to_i)
    Entry.find(ids).each do |entry|
      entry.photos.each do |photo|
        photo.lens = lens
        photo.camera = camera
        photo.save!
        puts "Photo #{photo.id} updated"
      end
    end
    plustek_camera = Camera.find_by!(display_name: 'Plustek OpticFilm 8200')
    plustek_camera.destroy if plustek_camera.photos.count == 0
    plustek_lens = Camera.find_by!(display_name: 'Plustek Nikkor 50mm f/1.4 AI')
    plustek_lens.destroy if plustek_lens.photos.count == 0
  end
end
