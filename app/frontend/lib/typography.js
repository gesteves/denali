// The part of `Typography` that changes a LENGTH, in the browser.
//
// ⚠️ It writes no quotation mark, and that is correct: `"` becomes `“` and `'` becomes `’`, one
// character in place of one, so the direction of a quote cannot change a count. Deciding that
// direction is the hard half of SmartyPants and the half no small copy could match — and it does
// not have to be matched.
//
// ⚠️ **This file is for the COUNT and must never render text a person reads.** It would give a
// post with straight quotes.
//
// ⚠️ A URL passes through untouched, for the same reason as in the Ruby: `example.com/a--b` would
// otherwise become an en dash, and that link is dead.

// The bare-URL rule of `Bluesky::URL_PATTERN`: everything up to whitespace, with `trimUrl` then
// deciding where the address actually ends.
const URL = /(?:^|[$|\W])(https?:\/\/\S+)/g;

// `Bluesky::MENTION_PATTERN`. ⚠️ A mention is masked for the same reason as an address: an IDN
// handle starts with `xn--`, which the dash rule would turn into an en dash and count one short.
const MENTION = /(?:^|[$|\W])(@(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)/g;

// `Bluesky::URL_TERMINAL` and `Bluesky::URL_WRAPPERS`.
const URL_TERMINAL = /[\p{Alphabetic}\p{Nd}\-_~/#@$&*+=%]/u;
const URL_WRAPPERS = { ')': '(', ']': '[', '>': '<', '}': '{' };

const countOf = (text, char) => text.split(char).length - 1;

/**
 * Whether an address can stop at its last character.
 * @param {string} url - The candidate address.
 * @returns {boolean} True when the last character belongs to the address.
 */
function endsHere (url) {
  const last = url.at(-1);
  if (URL_TERMINAL.test(last)) return true;

  // A closing bracket belongs to the address only when the address opened it.
  const opener = URL_WRAPPERS[last];
  return Boolean(opener) && countOf(url, opener) >= countOf(url, last);
}

/**
 * Removes whatever at the end of a match belongs to the sentence rather than the address.
 * @param {string} url - The address as matched.
 * @returns {string} The address alone.
 */
function trimUrl (url) {
  let out = String(url);
  while (out !== '' && !endsHere(out)) out = out.slice(0, -1);
  return out;
}

// One character standing in for an address while the rules run. U+FFFC is OBJECT REPLACEMENT
// CHARACTER, and it is one grapheme, so a mask can't change a count either.
const PLACEHOLDER = '￼';

// Longest first: four dashes give "—-" and five give "—–".
const RULES = [
  [/\.\.\./g, '…'],
  [/\. \. \./g, '…'],
  [/---/g, '—'],
  [/--/g, '–']
];

/**
 * Applies the typography rules that change a character count.
 * @param {string} text - The text as the author wrote it.
 * @returns {string} The text with ellipses and dashes collapsed, addresses untouched.
 */
export function apply (text) {
  // The text itself must not hold the mask, or the addresses would go back in the wrong places.
  let source = String(text ?? '').replaceAll(PLACEHOLDER, '');
  if (source === '') return source;

  const masked = [];
  URL.lastIndex = 0;
  source = source.replace(URL, (whole, url) => {
    const trimmed = trimUrl(url);
    if (trimmed === '') return whole;

    masked.push(trimmed);
    // Keep whatever came before the address, and whatever the trim took off the end: the pattern
    // consumes one character of boundary, and the punctuation still needs its typography.
    return whole.slice(0, whole.length - url.length) + PLACEHOLDER + url.slice(trimmed.length);
  });

  // Mentions are masked after the addresses, so a handle inside a URL is already covered.
  MENTION.lastIndex = 0;
  source = source.replace(MENTION, (whole, handle) => {
    masked.push(handle);
    return whole.slice(0, whole.length - handle.length) + PLACEHOLDER;
  });

  let converted = source;
  for (const [pattern, replacement] of RULES) converted = converted.replace(pattern, replacement);

  // Hand back the text unchanged if a mask went missing, as the Ruby does.
  let index = -1;
  const masks = converted.split(PLACEHOLDER).length - 1;
  if (masks !== masked.length) return String(text ?? '');

  return converted.replaceAll(PLACEHOLDER, () => masked[++index]);
}
