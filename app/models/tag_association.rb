class TagAssociation < ApplicationRecord
  belongs_to :blog, optional: true
  acts_as_taggable_on :tags
end
