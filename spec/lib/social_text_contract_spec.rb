require 'rails_helper'

# The Ruby half of the contract between app/lib/bluesky.rb and app/frontend/lib/*.js.
#
# The admin's character counter disables the submit button, so a browser that counts differently
# from the server either refuses a draft Bluesky would take or lets through one it won't.
# app/frontend/lib/social_text_contract.test.js reads the same fixture and asserts the same
# numbers, so a rule added on one side and not the other fails a test.
RSpec.describe 'the social text contract' do
  let(:drafts) do
    JSON.parse(Rails.root.join('spec/fixtures/social_text_drafts.json').read)['drafts']
  end

  it 'has drafts to check' do
    expect(drafts.size).to be >= 15
  end

  it 'counts each draft the way the fixture says' do
    drafts.each do |draft|
      expect(Bluesky.post_length(draft['text']))
        .to eq(draft['length']), "expected #{draft['text'].inspect} to count #{draft['length']}"
    end
  end
end
