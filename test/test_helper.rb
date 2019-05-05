ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'sidekiq/testing'

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  def setup
    Sidekiq::Testing.fake!
    Sidekiq::Worker.clear_all
    Photo.all.each do |photo|
      photo.image.attach(io: File.open(Rails.root.join('test/fixtures/images/rusty.jpg')), filename: 'rusty.jpg') unless photo.image.attached?
    end

    Blog.all.each do |blog|
      blog.favicon.attach(io: File.open(Rails.root.join('test/fixtures/images/a.png')), filename: 'a.png') unless blog.favicon.attached?
      blog.touch_icon.attach(io: File.open(Rails.root.join('test/fixtures/images/a.png')), filename: 'a.png') unless blog.touch_icon.attached?
      blog.logo.attach(io: File.open(Rails.root.join('test/fixtures/images/a.png')), filename: 'a.png') unless blog.logo.attached?
    end
  end

  # Add more helper methods to be used by all tests here...
end
