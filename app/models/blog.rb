class Blog < ApplicationRecord
  include Formattable

  has_many :entries, dependent: :destroy
  validates :name, :description, :about, presence: true

  def formatted_description
    markdown_to_html(self.description)
  end

  def plain_description
    markdown_to_plaintext(self.description)
  end

  def formatted_about
    markdown_to_html(self.about)
  end

  def plain_about
    markdown_to_plaintext(self.about)
  end
end
