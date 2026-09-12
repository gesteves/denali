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

// The bare-URL rule of `Bluesky::URL_PATTERN` and `Bluesky.trim_url`, together: everything up to
// whitespace, then whatever at the end belongs to the sentence comes off.
const URL = /(?:^|[$|\W])(https?:\/\/\S+)/g;
const URL_TRAILING_PUNCTUATION = /[.,;:!?]+$/;
const URL_TRAILING_WRAPPERS = { ')': '(', ']': '[', '>': '<' };

/**
 * Removes the punctuation of the sentence from the end of an address.
 * @param {string} url - The address as matched.
 * @returns {string} The address alone.
 */
function trimUrl (url) {
  let out = url.replace(URL_TRAILING_PUNCTUATION, '');

  // A closing bracket comes off only when the address holds no opening one.
  while (URL_TRAILING_WRAPPERS[out.at(-1)] && !out.includes(URL_TRAILING_WRAPPERS[out.at(-1)])) {
    out = out.slice(0, -1).replace(URL_TRAILING_PUNCTUATION, '');
  }

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

  const urls = [];
  URL.lastIndex = 0;
  source = source.replace(URL, (whole, url) => {
    const trimmed = trimUrl(url);
    if (trimmed === '') return whole;

    urls.push(trimmed);
    // Keep whatever came before the address, and whatever the trim took off the end: the pattern
    // consumes one character of boundary, and the punctuation still needs its typography.
    return whole.slice(0, whole.length - url.length) + PLACEHOLDER + url.slice(trimmed.length);
  });

  let converted = source;
  for (const [pattern, replacement] of RULES) converted = converted.replace(pattern, replacement);

  // Hand back the text unchanged if a mask went missing, as the Ruby does.
  let index = -1;
  const masks = converted.split(PLACEHOLDER).length - 1;
  if (masks !== urls.length) return String(text ?? '');

  return converted.replaceAll(PLACEHOLDER, () => urls[++index]);
}
