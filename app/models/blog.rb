class Blog < ActiveRecord::Base
  include Formattable

  has_many :entries, dependent: :destroy
  has_many :slack_incoming_webhooks, dependent: :destroy
  validates :name, :description, presence: true

  def formatted_description
    markdown_to_html(self.description)
  end

  def plain_description
    markdown_to_plaintext(self.description)
  end
end
