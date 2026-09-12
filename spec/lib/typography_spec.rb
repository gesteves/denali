require 'rails_helper'

RSpec.describe Typography do
  describe '.apply' do
    it 'curls quotes and apostrophes' do
      expect(described_class.apply(%q{It's a "big" day})).to eq('It’s a “big” day')
    end

    it 'collapses three dots into an ellipsis' do
      expect(described_class.apply('Wait for it...')).to eq('Wait for it…')
    end

    it 'converts dashes' do
      expect(described_class.apply('a -- b')).to eq('a – b')
      expect(described_class.apply('a --- b')).to eq('a — b')
    end

    it 'decodes the entities SmartyPants emits, because a post holds characters' do
      expect(described_class.apply("It's here")).not_to include('&')
    end

    it 'leaves the characters of a URL alone' do
      # SmartyPants reads each of these as punctuation, and every one of them is a dead link.
      url = 'https://example.com/a--b...c?q="d"&e=1'

      expect(described_class.apply("See #{url} now")).to eq("See #{url} now")
    end

    it 'applies typography to the words around a URL' do
      result = described_class.apply(%q{It's at https://example.com/a--b now...})

      expect(result).to eq('It’s at https://example.com/a--b now…')
    end

    it 'curls a quote that opens before a URL and closes after it' do
      # The mask is what makes this work: SmartyPants decides which way a quote curls from the
      # characters on either side, so it has to read the whole sentence at once.
      result = described_class.apply('He said "see https://example.com now"')

      expect(result).to eq('He said “see https://example.com now”')
    end

    it 'leaves an IDN handle alone' do
      # An IDN handle starts with "xn--", which SmartyPants would turn into an en dash.
      expect(described_class.apply('Hi @xn--bcher-kva.example.com!')).to include('@xn--bcher-kva.example.com')
    end

    it 'strips the placeholder out of the text it is given' do
      # The text must not be able to hold the mask, or the addresses would go back in the wrong
      # places.
      result = described_class.apply("a#{described_class::PLACEHOLDER}b")

      expect(result).to eq('ab')
    end

    it 'returns an empty string for nil' do
      expect(described_class.apply(nil)).to eq('')
    end
  end
end
