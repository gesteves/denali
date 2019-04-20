class TagAssociation < ApplicationRecord
  belongs_to :blog, optional: true
end
