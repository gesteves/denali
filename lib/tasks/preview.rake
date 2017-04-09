namespace :preview do
  task :hash => [:environment] do
    sha256 = Digest::SHA256.new
    Entry.find_each do |e|
      e.preview_hash = sha256.hexdigest(e.created_at.to_i.to_s)
      e.save
    end
  end
end
