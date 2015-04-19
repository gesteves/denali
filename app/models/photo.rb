class Photo < ActiveRecord::Base
  belongs_to :entry, touch: true
  acts_as_list scope: :entry
  has_attached_file :image
  validates_attachment_content_type :image,
    content_type: /image\/jpe?g/,
    storage: :s3,
    s3_credentials: "#{Rails.root}/config/s3.yml",
    url: ':s3_domain_url'
end
