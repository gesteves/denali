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
    photo = photos(:peppers)

    old_time = photo.entry.updated_at

    photo.caption = 'Foobar'
    photo.save

    new_time = photo.entry.updated_at
    assert_not_equal new_time, old_time
  end
end
