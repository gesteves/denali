// The Markdown-link grammar of `Bluesky`, in the browser.
//
// ⚠️ This is a copy of `app/lib/markdown_links.rb`, and `spec/fixtures/social_text_drafts.json`
// pins the two together: both files count the same drafts, and a difference fails a test on each
// side. It exists because the character counter has to follow every keystroke, and the count it
// shows disables the submit button.
//
// ⚠️ It carries no offsets, on purpose. Ruby counts code points and JavaScript counts UTF-16 code
// units, so an offset from this file would be a number that looks right and is not. Nothing in the
// browser needs one.

// One definition line: `[name]: https://example.com`. Anchored by the caller, so it never matches
// across a newline.
const DEFINITION = /^[ ]{0,3}\[([^[\]]+)\]:[ \t]*(\S+)[ \t]*$/;

// One span: the words in brackets, then an inline address or the name of a definition.
const SPAN = /\[([^[\]]*)\](?:\(([^\s()]+)\)|\[([^[\]]*)\])?/g;

// The addresses a link may hold.
const URL = /^https?:\/\/[^\s<>]+$/;

// ⚠️ These name the characters rather than using \s or trim(). JavaScript reads \s as Unicode and
// Ruby reads it as ASCII, so a label of one no-break space would mean different things in the two
// files.
const TRIM = /^[ \t\r\n]+|[ \t\r\n]+$/g;
const BLANK = /^[ \t\r\n]*$/;

const trim = (value) => String(value ?? '').replace(TRIM, '');
const isBlank = (value) => BLANK.test(String(value ?? ''));
const isUrl = (value) => URL.test(String(value ?? ''));
const nameKey = (name) => trim(name).toLowerCase();

/**
 * Takes the definition lines out of the text.
 * @param {string} source - The text as the author wrote it.
 * @returns {{text: string, definitions: Map<string, string>}}
 */
function splitDefinitions (source) {
  const definitions = new Map();
  const kept = [];

  for (const line of String(source ?? '').replace(/\r\n/g, '\n').split('\n')) {
    const match = DEFINITION.exec(line);
    // A line whose address isn't http or https isn't a definition; it stays as the words it is.
    if (match && isUrl(match[2])) {
      definitions.set(nameKey(match[1]), match[2]);
    } else {
      kept.push(line);
    }
  }

  return { text: trim(kept.join('\n')), definitions };
}

/**
 * Where one span points.
 * @param {RegExpExecArray} match - A match of SPAN.
 * @param {Map<string, string>} definitions - The addresses by name.
 * @returns {string|null} The address, or null when the span is only words.
 */
function urlOf (match, definitions) {
  const [, label, inline, reference] = match;
  // A link with no words has nothing to tap.
  if (isBlank(label)) return null;

  // `[words][]` and `[words]` both name the words, so one branch covers them both.
  const name = isBlank(reference) ? label : reference;
  const url = inline ?? definitions.get(nameKey(name));
  return isUrl(url) ? url : null;
}

/**
 * The plain text a post will hold, with its Markdown links reduced to their words.
 * @param {string} source - The text as the author wrote it.
 * @returns {string} The plain text.
 */
export function render (source) {
  const { text, definitions } = splitDefinitions(source);
  let out = '';
  let last = 0;

  SPAN.lastIndex = 0;
  let match;
  while ((match = SPAN.exec(text)) !== null) {
    // Leave a span that isn't a link exactly as it is, brackets and all. The next match copies the
    // words between `last` and its own start, so nothing is lost.
    if (urlOf(match, definitions) === null) continue;

    out += text.slice(last, match.index) + match[1];
    last = match.index + match[0].length;
  }

  return out + text.slice(last);
}
