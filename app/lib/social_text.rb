# Text rules shared by the social networks we post to: what counts as a URL, and how long a post is.
#
# Bluesky and Typography both read them from here, so the character counter, the typography and the
# code that builds facets can never disagree about where an address starts and ends.
module SocialText
  module_function

  # Finds every bare URL in the text and returns their character ranges.
  #
  # This uses Bluesky::URL_PATTERN, which is what decides whether a link facet gets created, so a
  # string that becomes a link on Bluesky is treated as an address everywhere else too.
  #
  # @param text [String, nil] the text to scan.
  # @return [Array<Range>] one character range per URL, in the order they appear.
  def url_ranges(text)
    ranges = []
    text.to_s.scan(Bluesky::URL_PATTERN) do
      start_char, end_char = Regexp.last_match.offset(1)
      ranges << (start_char...end_char)
    end
    ranges
  end

  # Counts the text in Unicode grapheme clusters, which is how Bluesky counts and how a reader sees
  # it. String#length counts a single emoji as two or more code units.
  #
  # @param text [String, nil] the text to measure.
  # @return [Integer] the number of grapheme clusters.
  def graphemes(text)
    text.to_s.scan(/\X/).length
  end
end
