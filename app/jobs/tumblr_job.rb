class TumblrJob < ApplicationJob
  queue_as :default

  def perform(entry)
    tumblr = Tumblr::Client.new({
      consumer_key: ENV['tumblr_consumer_key'],
      consumer_secret: ENV['tumblr_consumer_secret'],
      oauth_token: ENV['tumblr_access_token'],
      oauth_token_secret: ENV['tumblr_access_token_secret']
    })

    tags = entry.combined_tag_list
    tags += ENV['tumblr_tags'].split(/,\s*/) if ENV['tumblr_tags'].present?
    opts = {
      tags: tags.join(', '),
      slug: entry.slug,
      caption: entry.formatted_content(link_title: true),
      link: entry.permalink_url(utm_source: 'tumblr.com', utm_medium: 'social'),
      data: entry.photos.map { |p| resized_photo_path(p) },
      state: 'queue'
    }

    response = tumblr.photo(ENV['tumblr_domain'], opts)
    if response['errors'].present?
      raise response.to_s
    end
  end

  # Use rmagick instead of imgix to resize images for Tumblr,
  # because imgix strips exif data, and I still want the exif
  # displayed in the Tumblr theme.
  # Also Tumblr has a 10MB file size limit, so uploading the original
  # full-size image doesn't always work.
  def resized_photo_path(photo)
    file = Tempfile.new([photo.id.to_s, '.jpg'])
    original = Magick::Image::from_blob(open(photo.original_url).read).first
    image = original.resize_to_fit(2560)
    image.write(file.path)
    file.path
  end
end
