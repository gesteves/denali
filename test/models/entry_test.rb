require 'test_helper'

class EntryTest < ActiveSupport::TestCase
  test 'should not save entry without title' do
    entry = Entry.new(body: 'Test')
    assert_not entry.save
  end

  test 'should set slug before saving' do
    title = 'This is my title'
    entry = Entry.new(title: title, body: 'Whatever.')
    entry.save
    assert_equal title.parameterize, entry.slug
  end

  test 'should be draft' do
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'draft')
    entry.save
    assert entry.is_draft?
  end

  test 'should be queued' do
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'queued')
    entry.save
    assert entry.is_queued?
  end

  test 'should be published' do
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'published')
    entry.save
    assert entry.is_published?
  end

  test 'should change drafts to published' do
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'draft')
    entry.save
    entry.publish
    assert entry.is_published?
  end

  test 'should change queued to published' do
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'queued')
    entry.save
    entry.publish
    assert entry.is_published?
  end

  test 'should change drafts to queued' do
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'draft')
    entry.save
    entry.queue
    assert entry.is_queued?
  end

  test 'should change queued to draft' do
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'queued')
    entry.save
    entry.draft
    assert entry.is_draft?
  end

  test 'should not change published to queued' do
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'published')
    entry.save
    entry.queue
    assert entry.is_published?
  end

  test 'should not change published to draft' do
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'published')
    entry.save
    entry.draft
    assert entry.is_published?
  end

  test 'publish should set published_at' do
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'queued')
    entry.save
    entry.publish
    assert_not_nil entry.published_at
  end

  test 'draft should not set published_at' do
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'queued')
    entry.save
    entry.draft
    assert_nil entry.published_at
  end

  test 'queue should not set published_at' do
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'draft')
    entry.save
    entry.queue
    assert_nil entry.published_at
  end

  test 'publish should not set position' do
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'queued')
    entry.save
    entry.publish && entry.update_position
    assert_nil entry.position
  end

  test 'draft should not set position' do
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'queued')
    entry.save
    entry.draft && entry.update_position
    assert_nil entry.position
  end

  test 'queue should set position' do
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'draft')
    entry.save
    entry.queue && entry.update_position
    assert_not_nil entry.position
  end

  test 'published_at should not change' do
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'queued')
    entry.save
    entry.publish
    published_at = entry.published_at
    entry.publish
    assert_equal published_at, entry.published_at
  end

  test 'entry formatting should work' do
    entry = Entry.new(title: 'This is the *title* you\'re looking for', body: 'This is the *body* you\'re looking for.', status: 'queued')
    entry.save
    assert_equal entry.plain_title, 'This is the title you’re looking for'
    assert_equal entry.formatted_body, "<p>This is the <em>body</em> you&rsquo;re looking for.</p>\n"
    assert_equal entry.plain_body, 'This is the body you’re looking for.'
    assert_equal entry.formatted_content, "<p>This is the <em>title</em> you&rsquo;re looking for</p>\n\n<p>This is the <em>body</em> you&rsquo;re looking for.</p>\n"
  end
end
