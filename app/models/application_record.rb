class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def cache_key
    cache_version = Rails.configuration.action_controller.perform_caching ? ENV['CACHE_VERSION'] : Time.now.to_i
    if cache_version.present?
      "#{cache_version}/#{super}"
    else
      super
    end
  end

  def self.collection_cache_key(collection, timestamp_column)
    cache_version = Rails.configuration.action_controller.perform_caching ? ENV['CACHE_VERSION'] : Time.now.to_i
    if cache_version.present?
      "#{cache_version}/#{super}"
    else
      super
    end
  end
end
