namespace :storage do
  task :prepare => :environment do
    puts "Preparing Paperclip for removal!"
    puts "Storing blog attachment URLs in temporary rows."
    counter = 0
    Blog.find_each.each do |blog|
      blog.paperclip_favicon_url = blog.favicon.url
      blog.paperclip_touch_icon_url = blog.touch_icon.url
      blog.paperclip_logo_url = blog.logo.url
      blog.save!
      counter += 1
    end
    puts "#{counter} out of #{Blog.count} blogs updated."
    puts "Storing photo attachment URLs in temporary rows."
    counter = 0
    Photo.find_each.each do |photo|
      photo.paperclip_image_url = photo.image.url
      photo.save!
      counter += 1
    end
    puts "#{counter} out of #{Photo.count} photos updated."
  end
end
