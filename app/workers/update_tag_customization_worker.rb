class UpdateTagCustomizationWorker < ApplicationWorker
  sidekiq_options queue: 'low'

  def perform(tag_customization_id)
    tag_customization = TagCustomization.find(tag_customization_id)
    tag_customization.flickr_groups = tag_customization.flickr_groups
                                        &.split(/\s+/)
                                        &.uniq
                                        &.map { |g| get_group_alias_url(g) }
                                        &.uniq
                                        &.sort
                                        &.join("\n")
    tag_customization.save
  end

  private

  def get_group_alias_url(group_url)
    old_slug = group_url.split('/').last
    new_slug = begin
      if /\d+@N\d+/.match? old_slug
        flickr = FlickRaw::Flickr.new ENV['FLICKR_CONSUMER_KEY'], ENV['FLICKR_CONSUMER_SECRET']
        flickr.access_token = ENV['FLICKR_ACCESS_TOKEN']
        flickr.access_secret = ENV['FLICKR_ACCESS_TOKEN_SECRET']
        group_info = flickr.groups.getInfo(group_id: old_slug)
        group_info['path_alias'].blank? ? group_info['nsid'] : group_info['path_alias']
      else
        old_slug
      end
    rescue FlickRaw::FailedResponse
      old_slug
    end
    "https://www.flickr.com/groups/#{new_slug}/"
  end
end
