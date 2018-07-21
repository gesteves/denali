class Camera < ApplicationRecord
  has_many :photos
  validates :slug, uniqueness: true

  def article
    %w(a e i o u).include?(self.display_name[0].downcase) ? 'an' : 'a'
  end
end
