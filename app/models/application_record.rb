class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def cache_key
    "#{ENV['HEROKU_RELEASE_VERSION']}/#{ENV['CACHE_VERSION']}/#{super}"
  end

  def self.collection_cache_key(collection, timestamp_column)
    "#{ENV['HEROKU_RELEASE_VERSION']}/#{ENV['CACHE_VERSION']}/#{super}"
  end
end
