class Blog < ApplicationRecord
  include Formattable

  has_many :entries, dependent: :destroy

  has_one_attached :favicon
  has_one_attached :touch_icon
  has_one_attached :logo

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

  def favicon_url(opts = {})
    opts.reverse_merge!(w: 16)
    Ix.path(self.favicon.key).to_url(opts.reject { |k,v| v.blank? })
  end

  def touch_icon_url(opts = {})
    opts.reverse_merge!(w: 32)
    Ix.path(self.touch_icon.key).to_url(opts.reject { |k,v| v.blank? })
  end

  def logo_url(opts = {})
    opts.reverse_merge!(h: 60)
    Ix.path(self.logo.key).to_url(opts.reject { |k,v| v.blank? })
  end

  def has_search?
    Rails.env.development? || ENV['ELASTICSEARCH_URL'].present?
  end
end
