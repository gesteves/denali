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

// The bare-URL rule of `Bluesky::URL_PATTERN`. Only the address itself, as a global match.
const URL = /(?:^|[$|\W])(https?:\/\/[a-zA-Z0-9\-._~:/?#[\]@!$&'()*+,;%=]*[a-zA-Z0-9\-_~/#@$&*+=)])/g;

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
    urls.push(url);
    // Keep whatever came before the address: the pattern consumes one character of boundary.
    return whole.slice(0, whole.length - url.length) + PLACEHOLDER;
  });

  let converted = source;
  for (const [pattern, replacement] of RULES) converted = converted.replace(pattern, replacement);

  // Hand back the text unchanged if a mask went missing, as the Ruby does.
  let index = -1;
  const masks = converted.split(PLACEHOLDER).length - 1;
  if (masks !== urls.length) return String(text ?? '');

  return converted.replaceAll(PLACEHOLDER, () => urls[++index]);
}
