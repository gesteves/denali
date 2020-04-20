class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def cache_key
    cache_version = ENV['CACHE_VERSION']
    if cache_version.present?
      "#{cache_version}/#{super}"
    else
      super
    end
  end

  def self.collection_cache_key(collection, timestamp_column)
    cache_version = ENV['CACHE_VERSION']
    if cache_version.present?
      "#{cache_version}/#{super}"
    else
      super
    end
  end
end
