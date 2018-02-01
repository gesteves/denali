class TumblrJob < ApplicationJob
  queue_as :default

  def perform(entry)
    tumblr = Tumblr::Client.new({
      consumer_key: ENV['tumblr_consumer_key'],
      consumer_secret: ENV['tumblr_consumer_secret'],
      oauth_token: ENV['tumblr_access_token'],
      oauth_token_secret: ENV['tumblr_access_token_secret']
    })

    opts = {
      tags: custom_hashtags(entry),
      slug: entry.slug,
      caption: entry.formatted_content(link_title: true),
      link: entry.permalink_url,
      data: entry.photos.map { |p| open(p.url(w: 2560, fm: 'jpg')).path },
      state: 'queue'
    }

    response = tumblr.photo(ENV['tumblr_domain'], opts)
    if response['errors'].present?
      raise response['errors']
    elsif response['status'].present? && response['status'] >= 400
      raise response['msg']
    end
  end

  private

  # Checks the entry's tags; if it includes any of the keys in the hashtags.yml
  # as a tag, then it appends the list under that key as additional hashtags
  # for tumblr
  def custom_hashtags(entry)
    entry_tags = entry.combined_tags.map { |t| t.slug.gsub(/-/, '') }
    tumblr_tags = []
    custom_hashtags = YAML.load_file(Rails.root.join('config/hashtags.yml'))['tumblr']
    custom_hashtags.each do |k, v|
      if k == 'all'
        tumblr_tags += custom_hashtags[k]
      elsif entry_tags.include? k
        tumblr_tags += custom_hashtags[k]
      end
    end
    tags = tumblr_tags + entry.combined_tags.map(&:name)
    tags.sort.map(&:downcase).join(', ')
  end
end
