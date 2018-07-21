class Camera < ApplicationRecord
  has_many :photos
  validates :slug, presence: true, uniqueness: true
  validates :make, presence: true
  validates :model, presence: true
  validates :display_name, presence: true

  def article
    %w(a e i o u).include?(self.display_name[0].downcase) ? 'an' : 'a'
  end
end
