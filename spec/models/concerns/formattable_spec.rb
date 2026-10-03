require 'rails_helper'

RSpec.describe Formattable do
  let(:formatter) do
    Class.new do
      include Formattable
      public :markdown_to_html, :markdown_to_plaintext
    end.new
  end

  describe '#markdown_to_html' do
    it 'renders Markdown with typographic punctuation' do
      expect(formatter.markdown_to_html("It's *here*")).to eq("<p>It&rsquo;s <em>here</em></p>\n")
    end

    it 'is html_safe, since its output goes into views as is' do
      expect(formatter.markdown_to_html('x')).to be_html_safe
    end

    it 'renders nil as an empty string' do
      expect(formatter.markdown_to_html(nil)).to eq('')
    end
  end

  describe '#markdown_to_plaintext' do
    it 'drops the markup and decodes entities' do
      expect(formatter.markdown_to_plaintext("It's *bold* & [linked](https://example.com)")).to eq("It’s bold & linked")
    end

    it 'keeps paragraph breaks, collapsing extra blank lines' do
      expect(formatter.markdown_to_plaintext("One\n\n\n\nTwo")).to eq("One\n\nTwo")
    end

    it 'returns nil for nothing' do
      expect(formatter.markdown_to_plaintext(nil)).to be_nil
    end
  end
end
