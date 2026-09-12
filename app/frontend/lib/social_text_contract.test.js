import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { render } from './markdown_links';
import { apply } from './typography';

// The JavaScript half of the contract with app/lib/bluesky.rb.
//
// ⚠️ The character counter disables the submit button, so a browser that counts differently from
// the server either refuses a draft Bluesky would take or lets through one it won't.
// spec/lib/social_text_contract_spec.rb reads this same fixture and asserts the same numbers.
const { drafts } = JSON.parse(readFileSync('spec/fixtures/social_text_drafts.json', 'utf8'));

const segmenter = new Intl.Segmenter('en', { granularity: 'grapheme' });
const count = (text) => [...segmenter.segment(render(apply(text)))].length;

describe('the social text contract', () => {
  it('has drafts to check', () => {
    expect(drafts.length).toBeGreaterThanOrEqual(15);
  });

  it.each(drafts)('counts $text the way the server does', ({ text, length }) => {
    expect(count(text)).toBe(length);
  });
});
