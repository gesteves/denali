# Applies SmartyPants typography to a social post: curly quotes, a real ellipsis, and en and em
# dashes, from the characters someone types on a keyboard.
#
# This is the same typography as the blog, through Formattable#smartypants. A post and the entry it
# links to must not use a different apostrophe, so don't write a second set of rules here.
#
# A URL passes through unchanged, and that is the whole reason this class exists instead of calling
# the helper directly. SmartyPants reads the characters of an address as punctuation:
# `example.com/a--b` becomes an en dash, `/a...b` becomes an ellipsis, and `?q="a"` becomes curly
# quotes. Each one is a dead link, and nothing reports it.
class Typography
  # Extending the helper is what keeps this class from holding a rule of its own.
  extend Formattable

  # What each address becomes while SmartyPants reads the text. U+FFFC is OBJECT REPLACEMENT
  # CHARACTER, which is exactly what it says: one character standing in for something that isn't
  # text.
  #
  # The mask is necessary and splitting the text at each address is not enough. SmartyPants decides
  # which way a quote curls from the characters on either side of it, so it has to read the whole
  # sentence at once. Split, `He said "see <link> now"` opens the quote and never closes it,
  # because the two marks land in different pieces.
  PLACEHOLDER = "￼".freeze

  class << self
    # @param text [String, nil] the text as the author wrote it.
    # @return [String] the same text, with the site's typography applied everywhere but in a URL.
    def apply(text)
      # The text itself can't be allowed to hold the mask, or the addresses would go back in the
      # wrong places. That character isn't text and renders as nothing, so this loses no words.
      text = text.to_s.delete(PLACEHOLDER)
      return text if text.empty?

      urls = []
      converted = convert(mask(text, urls))

      # Hand back the text with no typography at all if a mask went missing. A straight apostrophe
      # is a small thing; an address that another address replaced is a link to the wrong page.
      return text unless converted.count(PLACEHOLDER) == urls.length

      index = -1
      converted.gsub(PLACEHOLDER) { urls[index += 1] }
    end

    private

    # Writes the text with one mask in place of each address, and collects those addresses.
    #
    # @param text [String] the text to mask.
    # @param urls [Array<String>] filled in, in the order the addresses appear.
    # @return [String] the masked text.
    def mask(text, urls)
      masked = +""
      last = 0

      masked_ranges(text).each do |range|
        masked << text[last...range.begin] << PLACEHOLDER
        urls << text[range]
        last = range.end
      end

      masked << text[last..].to_s
    end

    # SmartyPants writes HTML entities, because it's an HTML renderer: it gives `&rsquo;`, not `’`.
    # A post holds characters, so the decode is necessary, not decoration.
    #
    # @param chunk [String] the masked text.
    # @return [String] the text with typography applied and entities decoded.
    def convert(chunk)
      return chunk if chunk.empty?

      HTMLEntities.new.decode(smartypants(chunk).to_s)
    end

    # Every address and every mention, in order, with no overlaps: a mention that starts inside an
    # address is part of that address and doesn't get a mask of its own.
    #
    # Mentions are masked because an IDN handle starts with `xn--`, which SmartyPants would turn
    # into an en dash.
    #
    # @param text [String] the text to scan.
    # @return [Array<Range>] character ranges to mask, in order.
    def masked_ranges(text)
      urls = SocialText.url_ranges(text)
      tokens = []
      text.scan(Bluesky::MENTION_PATTERN) do
        start_char, end_char = Regexp.last_match.offset(1)
        tokens << (start_char...end_char) unless urls.any? { |range| range.cover?(start_char) }
      end
      (urls + tokens).sort_by(&:begin)
    end
  end
end
