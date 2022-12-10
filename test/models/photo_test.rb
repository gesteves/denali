require 'test_helper'

class PhotoTest < ActiveSupport::TestCase

  test 'updating a photo should update entry' do
    entry = entries(:peppers)

    original_updated_at = entry.updated_at

    entry.update! photos_attributes: { '0': { alt_text: 'Foo', id: entry.photos.first.id } }

    entry.reload

    new_updated_at = entry.updated_at
    assert_not_equal original_updated_at, new_updated_at
  end

  test 'territories are rendered correctly' do
    photo = photos(:peppers)
    assert photo.territories.blank?
    assert photo.territory_list.blank?

    photo = photos(:eastern)
    assert_equal "Shoshone-Bannock, Eastern Shoshone, and Cheyenne", photo.territory_list

    photo = photos(:panda)
    assert_equal "Shoshone-Bannock and Eastern Shoshone", photo.territory_list

    photo = photos(:franklin)
    assert_equal "Shoshone-Bannock", photo.territory_list
  end

  test 'mastodon focal points are correct' do
    photo = photos(:peppers)

    photo.focal_x = 0
    photo.focal_y = 0
    photo.save!
    assert_equal [-1.0, 1.0], photo.mastodon_focal_point

    photo.focal_x = 0.5
    photo.focal_y = 0.5
    photo.save!
    assert_equal [0, 0], photo.mastodon_focal_point

    photo.focal_x = 1.0
    photo.focal_y = 1.0
    photo.save!
    assert_equal [1.0, -1.0], photo.mastodon_focal_point
  end
end
