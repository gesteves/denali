ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  def setup
    Photo.all.each do |photo|
      photo.image.attach(io: File.open(Rails.root.join('test/fixtures/images/rusty.jpg')), filename: 'rusty.jpg')
    end

    Blog.all.each do |blog|
      blog.favicon.attach(io: File.open(Rails.root.join('test/fixtures/images/a.png')), filename: 'a.png')
      blog.touch_icon.attach(io: File.open(Rails.root.join('test/fixtures/images/a.png')), filename: 'a.png')
      blog.logo.attach(io: File.open(Rails.root.join('test/fixtures/images/a.png')), filename: 'a.png')
    end
  end

  # Add more helper methods to be used by all tests here...
end
