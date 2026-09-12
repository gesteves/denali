require 'rails_helper'

RSpec.describe SocialText do
  describe '.graphemes' do
    it 'counts plain characters' do
      expect(described_class.graphemes('Hello')).to eq(5)
    end

    it 'counts a family emoji as one grapheme' do
      expect(described_class.graphemes("\u{1F468}‍\u{1F469}‍\u{1F467}‍\u{1F466}")).to eq(1)
    end

    it 'counts a combining accent as one grapheme' do
      expect(described_class.graphemes("é")).to eq(1)
    end

    it 'counts nil as zero' do
      expect(described_class.graphemes(nil)).to eq(0)
    end
  end

  describe '.url_ranges' do
    it 'returns the character range of a bare URL' do
      text = 'See https://example.com now'
      ranges = described_class.url_ranges(text)

      expect(ranges.size).to eq(1)
      expect(text[ranges.first]).to eq('https://example.com')
    end

    it 'returns a range for each URL, in order' do
      text = 'https://a.example and https://b.example'
      ranges = described_class.url_ranges(text)

      expect(ranges.map { |r| text[r] }).to eq(['https://a.example', 'https://b.example'])
    end

    it 'stops before sentence punctuation' do
      text = 'Read https://example.com/a.'
      ranges = described_class.url_ranges(text)

      expect(text[ranges.first]).to eq('https://example.com/a')
    end

    it 'returns nothing for text with no URL' do
      expect(described_class.url_ranges('Just words')).to be_empty
    end
  end
end
