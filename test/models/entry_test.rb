require 'test_helper'

class EntryTest < ActiveSupport::TestCase

  test 'should not save entry without title' do
    user = users(:guille)
    blog = blogs(:allencompassingtrip)
    entry = Entry.new(body: 'Test', blog: blog, user: user)
    assert_not entry.save
  end

  test 'should set slug before saving' do
    user = users(:guille)
    blog = blogs(:allencompassingtrip)
    title = 'This is my title'
    entry = Entry.new(title: title, body: 'Whatever.', blog: blog, user: user)
    entry.save
    assert_equal title.parameterize, entry.slug
  end

  test 'should set preview hash before saving' do
    user = users(:guille)
    blog = blogs(:allencompassingtrip)
    title = 'This is my title'
    entry = Entry.new(title: title, body: 'Whatever.', blog: blog, user: user)
    entry.save
    assert_not_nil entry.preview_hash
  end

  test 'should be draft' do
    user = users(:guille)
    blog = blogs(:allencompassingtrip)
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'draft', blog: blog, user: user)
    entry.save
    assert entry.is_draft?
  end

  test 'should be queued' do
    user = users(:guille)
    blog = blogs(:allencompassingtrip)
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'queued', blog: blog, user: user)
    entry.save
    assert entry.is_queued?
  end

  test 'should be published' do
    user = users(:guille)
    blog = blogs(:allencompassingtrip)
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'published', blog: blog, user: user)
    entry.save
    assert entry.is_published?
  end

  test 'should change drafts to published' do
    user = users(:guille)
    blog = blogs(:allencompassingtrip)
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'draft', blog: blog, user: user)
    entry.save
    entry.publish
    assert entry.is_published?
  end

  test 'should change queued to published' do
    user = users(:guille)
    blog = blogs(:allencompassingtrip)
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'queued', blog: blog, user: user)
    entry.save
    entry.publish
    assert entry.is_published?
  end

  test 'should change drafts to queued' do
    user = users(:guille)
    blog = blogs(:allencompassingtrip)
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'draft', blog: blog, user: user)
    entry.save
    entry.queue
    assert entry.is_queued?
  end

  test 'should change queued to draft' do
    user = users(:guille)
    blog = blogs(:allencompassingtrip)
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'queued', blog: blog, user: user)
    entry.save
    entry.draft
    assert entry.is_draft?
  end

  test 'should not change published to queued' do
    user = users(:guille)
    blog = blogs(:allencompassingtrip)
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'published', blog: blog, user: user)
    entry.save
    entry.queue
    assert entry.is_published?
  end

  test 'should not change published to draft' do
    user = users(:guille)
    blog = blogs(:allencompassingtrip)
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'published', blog: blog, user: user)
    entry.save
    entry.draft
    assert entry.is_published?
  end

  test 'publish should set published_at & modified_at' do
    user = users(:guille)
    blog = blogs(:allencompassingtrip)
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'queued', blog: blog, user: user)
    entry.save
    assert_nil entry.published_at
    assert_nil entry.modified_at
    entry.publish
    assert_not_nil entry.published_at
    assert_not_nil entry.modified_at
  end

  test 'queuing should set a position' do
    user = users(:guille)
    blog = blogs(:allencompassingtrip)
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'queued', blog: blog, user: user)
    entry.save
    assert_not_nil entry.position
  end

  test 'publishing a queued post should clear the position' do
    user = users(:guille)
    blog = blogs(:allencompassingtrip)
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'queued', blog: blog, user: user)
    entry.save
    assert_not_nil entry.position
    entry.publish
    assert_nil entry.position
  end

  test 'draft should not set published_at' do
    user = users(:guille)
    blog = blogs(:allencompassingtrip)
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'queued', blog: blog, user: user)
    entry.save
    entry.draft
    assert_nil entry.published_at
  end

  test 'queue should not set published_at' do
    user = users(:guille)
    blog = blogs(:allencompassingtrip)
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'draft', blog: blog, user: user)
    entry.save
    entry.queue
    assert_nil entry.published_at
  end

  test 'publish should not set position' do
    user = users(:guille)
    blog = blogs(:allencompassingtrip)
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'queued', blog: blog, user: user)
    entry.save
    entry.publish
    assert_nil entry.position
  end

  test 'draft should not set position' do
    user = users(:guille)
    blog = blogs(:allencompassingtrip)
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'queued', blog: blog, user: user)
    entry.save
    entry.draft
    assert_nil entry.position
  end

  test 'queue should set position' do
    user = users(:guille)
    blog = blogs(:allencompassingtrip)
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'draft', blog: blog, user: user)
    entry.save
    entry.queue
    assert_not_nil entry.position
  end

  test 'published_at should not change' do
    user = users(:guille)
    blog = blogs(:allencompassingtrip)
    entry = Entry.new(title: 'Title', body: 'Body.', status: 'queued', blog: blog, user: user)
    entry.save
    entry.publish
    published_at = entry.published_at
    entry.publish
    assert_equal published_at, entry.published_at
  end

  test 'entry formatting should work' do
    user = users(:guille)
    blog = blogs(:allencompassingtrip)
    entry = Entry.new(title: 'This is the *title* you\'re looking for', body: 'This is the *body* you\'re looking for.', status: 'queued', blog: blog, user: user)
    entry.save
    assert_equal entry.plain_title, 'This is the title you’re looking for'
    assert_equal entry.formatted_body, "<p>This is the <em>body</em> you&rsquo;re looking for.</p>\n"
    assert_equal entry.plain_body, 'This is the body you’re looking for.'
    assert_equal entry.formatted_content, "<p>This is the <em>title</em> you&rsquo;re looking for</p>\n\n<p>This is the <em>body</em> you&rsquo;re looking for.</p>\n"
  end

  test 'entry positioning should work' do
    user = users(:guille)
    blog = blogs(:allencompassingtrip)
    entry_1 = entries(:panda)

    entry_2 = Entry.new(title: 'test 1', status: 'queued', blog: blog, user: user)
    entry_2.save
    entry_3 = Entry.new(title: 'test 2', status: 'queued', blog: blog, user: user)
    entry_3.save

    entry_1.move_lower
    assert_equal entry_1.position, 2

    entry_1.move_higher
    assert_equal entry_1.position, 1

    entry_1.move_to_bottom
    assert_equal entry_1.position, 3

    entry_1.move_to_top
    assert_equal entry_1.position, 1
  end

  test 'instagram hashtags should work' do
    entry = entries(:panda)
    assert_not_empty entry.instagram_hashtags
  end

  test 'adding tags' do
    entry = entries(:panda)
    entry.tag_list = 'Panda'
    entry.location_list = 'Washington'
    entry.equipment_list = 'Nikon'
    entry.style_list = 'Black & White'
    entry.save!
    entry.reload

    entry.add_tags('Panda, Washington, Mammal')
    assert entry.tag_list.include?('Panda')
    assert entry.location_list.include?('Washington')
    assert entry.style_list.include?('Black & White')

    assert entry.tag_list.include?('Mammal')
    assert !entry.tag_list.include?('Washington')
  end

  test 'checking if the queue has published today' do
    assert_not Entry.queue_has_published_today?
    entry = entries(:panda)
    entry.publish
    assert Entry.queue_has_published_today?
  end
end
