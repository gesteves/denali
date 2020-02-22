class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def cache_key
    if heroku_release_version = ENV['HEROKU_RELEASE_VERSION']
      "#{heroku_release_version}/#{super}"
    else
      super
    end
  end
end
