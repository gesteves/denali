module Formattable
  extend ActiveSupport::Concern

  private
  def markdown_to_html(text)
    renderer = HTMLWithPants.new
    markdown = Redcarpet::Markdown.new(renderer, extensions = {})
    text.nil? ? '' : markdown.render(text)
  end

  def markdown_to_plaintext(text)
    Sanitize.fragment(markdown_to_html(text)).strip
  end

  def smartypants(text)
    Redcarpet::Render::SmartyPants.render(text)
  end

  class HTMLWithPants < Redcarpet::Render::HTML
    include Redcarpet::Render::SmartyPants
  end
end
