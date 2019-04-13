class FlickrWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  def perform(photo_id)
    photo = Photo.find(photo_id)
    entry = photo.entry
    return if !entry.is_published? || !Rails.env.production?
    FlickRaw.api_key = ENV['flickr_consumer_key']
    FlickRaw.shared_secret = ENV['flickr_consumer_secret']

    flickr = FlickRaw::Flickr.new
    flickr.access_token = ENV['flickr_access_token']
    flickr.access_secret = ENV['flickr_access_token_secret']

    title = entry.title

    if entry.body.present?
      body = "#{entry.formatted_body}\n\n#{entry.permalink_url}"
    else
      body = entry.permalink_url
    end

    all_tags = entry.combined_tag_list.map { |t| "\"#{t.gsub(/["']/, '')}\"" }.join(' ')

    photo_id = flickr.upload_photo open(photo.image.service_url).path, title: title, description: body, tags: all_tags

    if photo_id.present?
      group_ids = flickr_groups(entry)
      group_ids.each do |group_id|
        FlickrGroupWorker(photo_id, group_id)
      end
    end
  end

  private
  def flickr_groups(entry, count = 60)
    groups = []
    extra_groups = []
    tags = entry.combined_tags.map { |t| t.slug.gsub(/-/, '') }
    flickr_groups = YAML.load_file(Rails.root.join('config/flickr_groups.yml'))
    flickr_groups.each do |k, v|
      if tags.include? k
        groups += flickr_groups[k]&.flatten&.uniq&.sample(5)
      end
    end
    if groups.uniq.size < count
      flickr_groups.each do |k, v|
        if tags.include? k
          extra_groups += flickr_groups[k]&.flatten&.uniq
        end
      end
    end
    final_groups = groups + extra_groups.shuffle
    final_groups.compact.uniq[0, count]
  end
end
