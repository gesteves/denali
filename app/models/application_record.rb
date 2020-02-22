class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def cache_key
    if cache_key_version = ENV['CACHE_KEY_VERSION']
      "#{cache_key_version}/#{super}"
    else
      super
    end
  end

  def self.collection_cache_key(collection, timestamp_column)
    if cache_key_version = ENV['CACHE_KEY_VERSION']
      "#{cache_key_version}/#{super}"
    else
      super
    end
  end
end
