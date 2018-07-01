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

  task :migrate => :environment do
    puts "Migrating blog attachments to Active Storage."
    counter = 0
    Blog.find_each.each do |blog|
      blog.favicon.attach(io: open(blog.paperclip_favicon_url),
                        filename: blog.favicon_file_name,
                        content_type: blog.favicon_content_type)
      blog.touch_icon.attach(io: open(blog.paperclip_touch_icon_url),
                              filename: blog.touch_icon_file_name,
                              content_type: blog.touch_icon_content_type)
      blog.logo.attach(io: open(blog.paperclip_logo_url),
                              filename: blog.logo_file_name,
                              content_type: blog.logo_content_type)
      counter += 1
    end
    puts "#{counter} out of #{Blog.count} blogs migrated."
    puts "Migrating photo attachments to Active Storage."
    counter = 0
    Photo.find_each.each do |photo|
      photo.image.attach(io: open(photo.paperclip_image_url),
                          filename: photo.image_file_name,
                          content_type: photo.image_content_type)
      counter += 1
    end
    puts "#{counter} out of #{Photo.count} photos migrated."
  end
end
