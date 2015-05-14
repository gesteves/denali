class Blog < ActiveRecord::Base
  include Formattable

  has_many :entries, dependent: :destroy
  validates :name, :description, presence: true
  validates :photo_quality, presence: true, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 }

  def formatted_description
    markdown_to_html(self.description)
  end

  def plain_description
    markdown_to_plaintext(self.description)
  end
end
