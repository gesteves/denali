require 'httparty'
require 'date'

namespace :import do
  desc 'Import posts from Tumblr'
  task :tumblr => [:environment] do
    blog = Blog.first
    user = User.first
    posts = get_tumblr_posts({ tag: ENV['TAG'], id: ENV['POST_ID'] }).sort{ |a, b| a['timestamp'] <=> b['timestamp'] }
    posts.each_with_index do |post, i|
      puts "Importing #{post['post_url']} (#{i + 1}/#{posts.size})"
      if Entry.where(tumblr_id: post['id']).count > 0
        puts "Post already exists, skipping it."
      else
        entry = Entry.new
        entry.title = post['caption']
        entry.slug = post['slug']
        entry.published_at = Time.at(post['timestamp']).to_datetime
        entry.status = 'published'
        entry.tag_list = post['tags'].reject{ |t| t =~ /^lens:model=|^film:name=/ }.uniq{ |t| t.downcase }.join(', ')
        entry.tumblr_id = post['id']
        post['photos'].each do |p|
          photo = Photo.new
          photo.source_url = p['original_size']['url']
          photo.caption = p['caption']
          entry.photos << photo
        end
        entry.blog = blog
        entry.user = user
        entry.save
      end
    end
  end
end

def get_tumblr_posts(options)
  options.reverse_merge! offset: 0, limit: 20
  if !options[:id].nil? && !options[:tag].nil?
    puts "Fetching post #{options[:id]} tagged with #{options[:tag]} "
  elsif !options[:id].nil?
    puts "Fetching post #{options[:id]}"
  elsif !options[:tag].nil?
    puts "Fetching posts tagged with #{options[:tag]} #{options[:offset] + 1}-#{options[:offset] + options[:limit]}"
  else
    puts "Fetching posts #{options[:offset] + 1}-#{options[:offset] + options[:limit]}"
  end
  posts = []
  url = "http://api.tumblr.com/v2/blog/#{ENV['tumblr_domain']}/posts/photo?api_key=#{ENV['tumblr_consumer_key']}&filter=text&offset=#{options[:offset]}&limit=#{options[:limit]}"
  url += "&tag=#{options[:tag]}" unless options[:tag].nil?
  url += "&id=#{options[:id]}" unless options[:id].nil?
  response = HTTParty.get(url)
  body = JSON.parse(response.body)
  posts << body['response']['posts']
  if body['response']['total_posts'] > options[:offset] + options[:limit]
    options[:offset] = options[:offset] + options[:limit]
    posts << get_tumblr_posts(options)
  end
  posts.flatten
end
