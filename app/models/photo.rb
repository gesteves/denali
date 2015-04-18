class Photo < ActiveRecord::Base
  belongs_to :entry, touch: true
  acts_as_list scope: :entry
end
