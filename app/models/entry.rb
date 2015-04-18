class Entry < ActiveRecord::Base
  belongs_to :blog, touch: true
  belongs_to :user
end
