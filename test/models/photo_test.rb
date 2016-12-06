require 'test_helper'

class PhotoTest < ActiveSupport::TestCase
  test 'photo formatting should work' do
    photo = photos(:peppers)
    photo.caption = 'This is the *caption* you\'re looking for.'
    photo.save
    assert_equal photo.plain_caption, 'This is the caption you’re looking for.'
    assert_equal photo.formatted_caption, "<p>This is the <em>caption</em> you&rsquo;re looking for.</p>\n"
  end

  test 'photo dimensions' do
    photo = photos(:peppers)
    assert photo.is_vertical?
    assert_not photo.is_square?
    assert_not photo.is_horizontal?
  end

  test 'updating a photo should update entry' do
    entry = entries(:peppers)

    original_updated_at = entry.updated_at

    entry.update! photos_attributes: { '0': { caption: 'Foo', id: entry.photos.first.id } }

    entry.reload

    new_updated_at = entry.updated_at
    assert_not_equal original_updated_at, new_updated_at
  end
end
