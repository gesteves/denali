require 'test_helper'

class PhotoTest < ActiveSupport::TestCase

  test 'photo dimensions' do
    photo = photos(:peppers)
    assert photo.is_vertical?
    assert_not photo.is_square?
    assert_not photo.is_horizontal?
  end

  test 'updating a photo should update entry' do
    entry = entries(:peppers)

    original_updated_at = entry.updated_at

    entry.update! photos_attributes: { '0': { alt_text: 'Foo', id: entry.photos.first.id } }

    entry.reload

    new_updated_at = entry.updated_at
    assert_not_equal original_updated_at, new_updated_at
  end

  test 'color detection' do
    photo = photos(:peppers)
    assert photo.color?
    assert_not photo.black_and_white?
  end

  test 'b&w detection' do
    photo = photos(:franklin)
    assert_not photo.color?
    assert photo.black_and_white?
  end
end
