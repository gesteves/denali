require 'rails_helper'

RSpec.describe MarkdownLinks do
  describe '.parse' do
    it 'reads an inline link' do
      result = described_class.parse('Read [my post](https://example.com/a) today')

      expect(result.text).to eq('Read my post today')
      expect(result.links.map(&:url)).to eq(['https://example.com/a'])
      expect(result.links.first.start).to eq(5)
      expect(result.links.first.finish).to eq(12)
    end

    it 'reads a reference link and removes its definition line' do
      result = described_class.parse("Read [my post][ref] today\n\n[ref]: https://example.com/a")

      expect(result.text).to eq('Read my post today')
      expect(result.links.map(&:url)).to eq(['https://example.com/a'])
    end

    it 'reads a collapsed reference link, where the words are the name' do
      result = described_class.parse("Read [ref] today\n\n[ref]: https://example.com/a")

      expect(result.text).to eq('Read ref today')
      expect(result.links.map(&:url)).to eq(['https://example.com/a'])
    end

    it 'folds the case of a reference name, as CommonMark does' do
      result = described_class.parse("Read [my post][Ref]\n\n[ref]: https://example.com/a")

      expect(result.links.map(&:url)).to eq(['https://example.com/a'])
    end

    it 'gives two links with the same words their own offsets' do
      result = described_class.parse('[docs](https://a.example) and [docs](https://b.example)')

      expect(result.text).to eq('docs and docs')
      expect(result.links.map { |l| [l.start, l.finish] }).to eq([[0, 4], [9, 13]])
    end

    it 'counts offsets in characters, not bytes' do
      result = described_class.parse('café [ünïcode](https://example.com/a)')

      expect(result.links.first.start).to eq(5)
      expect(result.links.first.finish).to eq(12)
    end

    it 'removes a definition line without leaving a blank line behind' do
      result = described_class.parse("Words\n\n[ref]: https://example.com/a")

      expect(result.text).to eq('Words')
    end

    it 'handles CRLF line endings' do
      result = described_class.parse("Read [a][ref]\r\n\r\n[ref]: https://example.com/a")

      expect(result.text).to eq('Read a')
      expect(result.links.map(&:url)).to eq(['https://example.com/a'])
    end

    it 'allows up to three spaces of indent on a definition line' do
      expect(described_class.parse("a\n   [ref]: https://example.com/a").text).to eq('a')
      expect(described_class.parse("a\n    [ref]: https://example.com/a").text)
        .to eq("a\n    [ref]: https://example.com/a")
    end

    context 'with spans that are not links' do
      # Every one of these has to stay exactly as written. This is the test that keeps an ordinary
      # sentence with brackets in it out of the grammar.
      {
        'a non-http address' => 'I ate [a lot](really)',
        'a reference with no definition' => 'Something [wild] happened',
        'bare brackets' => 'A [note] here',
        'a definition whose address is not http' => "See [a]\n\n[a]: mailto:me@example.com",
        'an empty label' => '[](https://example.com/a)'
      }.each do |name, draft|
        it "leaves #{name} alone" do
          result = described_class.parse(draft)

          expect(result.text).to eq(draft)
          expect(result.links).to be_empty
        end
      end
    end

    it 'returns empty text for nil' do
      result = described_class.parse(nil)

      expect(result.text).to eq('')
      expect(result.links).to be_empty
    end
  end

  describe '.render' do
    it 'returns just the text' do
      expect(described_class.render('Read [my post](https://example.com/a)')).to eq('Read my post')
    end

    it 'returns an empty string for nil' do
      expect(described_class.render(nil)).to eq('')
    end
  end

  describe '.links?' do
    it 'is true when the text holds a link' do
      expect(described_class.links?('[a](https://example.com)')).to be true
    end

    it 'is false for a sentence with brackets in it' do
      expect(described_class.links?('I ate [a lot](really)')).to be false
      expect(described_class.links?('Something [wild] happened')).to be false
    end

    it 'is false for a bare URL, which is not markdown' do
      expect(described_class.links?('Visit https://example.com')).to be false
    end
  end
end
