class Photo < ActiveRecord::Base
  belongs_to :entry, touch: true
  acts_as_list scope: :entry
  has_attached_file :image
  validates_attachment_content_type :image, :content_type => /image\/jpe?g/
end
