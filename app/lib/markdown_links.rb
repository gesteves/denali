# Parses the Markdown links in a social post and returns the plain text the post will hold, along
# with the position of each link's label in that text.
#
# This is a small grammar, not a Markdown renderer. It knows links and nothing else: no emphasis,
# no headings, no code, no escapes. A post is a few hundred characters of someone writing a
# sentence, and every other Markdown rule would only turn plain words into markup the author did
# not ask for — a hashtag at the start of a line read as a heading, an underscore read as emphasis,
# an asterisk eaten out of the middle of a caption.
#
# Three forms are supported:
#
#   [words](https://example.com)          inline
#   [words][name] … [name]: https://…     a reference, with its definition on its own line
#   [name] … [name]: https://…            a short reference, where the words are the name
#
# The address must be http or https. A span holding anything else is left exactly as written, so
# "I ate [a lot](really)" stays a sentence, brackets and parentheses and all.
class MarkdownLinks
  # One definition line: `[name]: https://example.com`. This matches a single line, and the caller
  # anchors it, so it never matches across a newline.
  DEFINITION_SOURCE = "[ ]{0,3}\\[([^\\[\\]]+)\\]:[ \\t]*(\\S+)[ \\t]*".freeze

  # One span: the words in brackets, then either an inline address or the name of a definition.
  # The second part is optional, which is the short form — `[name]` alone is a link when a
  # definition names it, and ordinary words when nothing does.
  SPAN_SOURCE = "\\[([^\\[\\]]*)\\](?:\\(([^\\s()]+)\\)|\\[([^\\[\\]]*)\\])?".freeze

  # The addresses a link may hold. This is the thing that keeps an ordinary sentence out of the
  # grammar.
  URL_SOURCE = "https?://[^\\s<>]+".freeze

  DEFINITION_PATTERN = /\A#{DEFINITION_SOURCE}\z/
  SPAN_PATTERN = Regexp.new(SPAN_SOURCE)
  URL_PATTERN = /\A#{URL_SOURCE}\z/

  # The whitespace a trim takes off each end, and a value that holds nothing else.
  #
  # These name the characters instead of using \s, String#strip or #blank?, so a label made of one
  # no-break space means the same thing here as it would in a browser, where \s is Unicode-aware
  # and Ruby's is ASCII.
  TRIM_PATTERN = /\A[ \t\r\n]+|[ \t\r\n]+\z/
  BLANK_PATTERN = /\A[ \t\r\n]*\z/

  # One link in a post: where its words are in the plain text, and where it points.
  #
  # `start` and `finish` are character offsets. Bluesky#link_facet turns them into the byte offsets
  # a facet needs; one accented letter is 1 character and 2 bytes.
  Link = Data.define(:start, :finish, :url)

  # The plain text of a post, and every link in it.
  Result = Data.define(:text, :links)

  class << self
    # Parses a post.
    #
    # @param source [String, nil] the text as the author wrote it, with the Markdown still in it.
    # @return [Result] the plain text, and a Link for each link in it.
    def parse(source)
      text, definitions = split_definitions(source.to_s)
      scan(text, definitions)
    end

    # @param source [String, nil] the text as the author wrote it.
    # @return [String] the plain text the post will hold.
    def render(source) = parse(source).text

    # @param source [String, nil] the text as the author wrote it.
    # @return [Boolean] true when the text holds at least one link.
    def links?(source) = parse(source).links.any?

    private

    # Takes the definition lines out of the text.
    #
    # A definition is a whole line, so this splits the text rather than substituting inside it. The
    # line goes away with its newline and the trim removes the blank line left behind, so a post
    # never carries the empty lines of its own syntax.
    #
    # @param source [String] the text.
    # @return [Array(String, Hash)] the text with no definition lines, and the addresses by name.
    def split_definitions(source)
      definitions = {}
      kept = []

      source.gsub("\r\n", "\n").split("\n", -1).each do |line|
        match = DEFINITION_PATTERN.match(line)
        # A line whose address is not http or https is not a definition, so it stays in the post as
        # the words it is.
        if match && url?(match[2])
          definitions[name_key(match[1])] = match[2]
        else
          kept << line
        end
      end

      [trim(kept.join("\n")), definitions]
    end

    # Writes the plain text and records where each label lands in it.
    #
    # This is one left-to-right pass and the offsets come from the text being written, so two links
    # with the same words each get their own offsets. Searching the finished text for a label —
    # which is what any render-to-HTML-then-match approach has to do — puts the facet over the
    # first occurrence of those words rather than over the link.
    #
    # @param text [String] the text with no definition lines left in it.
    # @param definitions [Hash] the addresses by name.
    # @return [Result]
    def scan(text, definitions)
      out = +""
      links = []
      last = 0

      text.scan(SPAN_PATTERN) do
        match = Regexp.last_match
        url = url_of(match, definitions)
        # Leave the span exactly as it is, brackets and all. The next match copies the words
        # between `last` and its own start, so nothing is lost.
        next if url.nil?

        out << text[last...match.begin(0)]
        start = out.length
        out << match[1]
        links << Link.new(start: start, finish: out.length, url: url)
        last = match.end(0)
      end

      Result.new(text: out + text[last..].to_s, links: links)
    end

    # Where one span points.
    #
    # @param match [MatchData] a match of SPAN_PATTERN.
    # @param definitions [Hash] the addresses by name.
    # @return [String, nil] the address, or nil when the span is only words.
    def url_of(match, definitions)
      label, inline, reference = match[1], match[2], match[3]
      # A link with no words has nothing to tap.
      return nil if blank?(label)

      # `[words][]` and `[words]` both name the words, so one branch covers them both.
      name = blank?(reference) ? label : reference
      url = inline || definitions[name_key(name)]
      url if url?(url)
    end

    # Folds case the way CommonMark does, so `[Name]: …` answers `[words][name]`.
    #
    # @param name [String] the reference name as written.
    # @return [String] the lookup key.
    def name_key(name) = trim(name.to_s).downcase

    # @param value [String, nil] the value to trim.
    # @return [String] the value with no whitespace at either end.
    def trim(value) = value.to_s.gsub(TRIM_PATTERN, "")

    # @param value [String, nil] the value to test.
    # @return [Boolean] true when the value holds nothing but whitespace.
    def blank?(value) = BLANK_PATTERN.match?(value.to_s)

    # @param value [String, nil] the value to test.
    # @return [Boolean] true when the value is an http or https address.
    def url?(value) = URL_PATTERN.match?(value.to_s)
  end
end
