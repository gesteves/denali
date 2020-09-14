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
  end

  # Add more helper methods to be used by all tests here...

  def set_up_images(entry)
    entry.photos.each do |photo|
      photo.image.attach(io: File.open(Rails.root.join('test/fixtures/images/rusty.jpg')), filename: 'rusty.jpg')
      photo.image.analyze
    end
  end

  def set_up_all_images
    Photo.all.each do |photo|
      photo.image.attach(io: File.open(Rails.root.join('test/fixtures/images/rusty.jpg')), filename: 'rusty.jpg')
      photo.image.analyze
    end
  end
end
