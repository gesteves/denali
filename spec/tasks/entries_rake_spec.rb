require 'rails_helper'

RSpec.describe 'entries rake tasks', type: :task do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }

  describe 'entries:set_search_engine_setting' do
    let!(:shareable) { create(:entry, :published, blog: blog, user: user, post_to_bluesky: true, hide_from_search_engines: true) }
    let!(:unshareable) do
      create(:entry, :published, blog: blog, user: user, hide_from_search_engines: false,
             post_to_bluesky: false, post_to_mastodon: false, post_to_instagram: false, post_to_threads: false)
    end

    it 'shows shareable entries to search engines and hides the rest' do
      run_task('entries:set_search_engine_setting')

      expect(shareable.reload.hide_from_search_engines).to be false
      expect(unshareable.reload.hide_from_search_engines).to be true
    end

    it 'changes nothing on a dry run' do
      run_task('entries:set_search_engine_setting', 'DRY_RUN' => 'true')

      expect(shareable.reload.hide_from_search_engines).to be true
      expect(unshareable.reload.hide_from_search_engines).to be false
    end
  end

  describe 'entries:disable_sharing' do
    let!(:tagged) { create(:entry, :published, blog: blog, user: user, tag_list: 'private', post_to_bluesky: true, post_to_mastodon: true) }
    let!(:other) { create(:entry, :published, blog: blog, user: user, tag_list: 'public', post_to_bluesky: true) }

    it 'turns off every network for entries with the tag' do
      run_task('entries:disable_sharing', 'TAG' => 'private')

      expect(tagged.reload.post_to_bluesky).to be false
      expect(tagged.post_to_mastodon).to be false
      expect(other.reload.post_to_bluesky).to be true
    end

    # `return` in a rake block raises LocalJumpError; nothing to do has to just stop.
    it 'reports when no entries match, without raising' do
      output = run_task('entries:disable_sharing', 'TAG' => 'nonexistent')
      expect(output).to include('No entries found')
    end
  end
end
