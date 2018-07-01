ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  Photo.all.each do |photo|
    puts "Attaching image to photo #{photo.id}…"
    photo.image.attach(io: File.open(Rails.root.join('test/fixtures/images/rusty.jpg')), filename: 'rusty.jpg')
  end

  Blog.all.each do |blog|
    puts "Attaching favicon to blog #{blog.name}…"
    blog.favicon.attach(io: File.open(Rails.root.join('test/fixtures/images/a.png')), filename: 'a.png')
    puts "Attaching touch icon to blog #{blog.name}…"
    blog.touch_icon.attach(io: File.open(Rails.root.join('test/fixtures/images/a.png')), filename: 'a.png')
    puts "Attaching logo to blog #{blog.name}…"
    blog.logo.attach(io: File.open(Rails.root.join('test/fixtures/images/a.png')), filename: 'a.png')
  end

  # Add more helper methods to be used by all tests here...
end
