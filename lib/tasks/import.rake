require 'httparty'
require 'date'

namespace :import do
  desc 'Import posts from Tumblr'
  task :tumblr => [:environment] do
    posts = get_tumblr_posts.sort{ |a, b| a['timestamp'] <=> b['timestamp'] }
    posts.each_with_index do |post, i|
      puts "Importing #{post['post_url']} (#{i + 1}/#{posts.size})"
      entry = Entry.new
      entry.title = post['caption']
      entry.slug = post['slug']
      entry.published_at = Time.at(post['timestamp']).to_datetime
      entry.status = 'published'
      entry.tag_list = post['tags'].reject{ |t| t =~ /^lens:model=|^film:name=/ }.join(', ')
      post['photos'].each do |p|
        photo = Photo.new
        photo.source_url = p['original_size']['url']
        photo.caption = p['caption']
        photo.camera_list = p['exif']['Camera'] unless p['exif'].nil? || p['exif']['Camera'].nil?
        photo.lense_list = post['tags'].select{|t| t =~ /^lens:model=/}.first.sub(/^lens:model=/,'') unless post['tags'].select{|t| t =~ /^lens:model=/}.first.nil?
        photo.film_list = post['tags'].select{|t| t =~ /^film:name==/}.first.sub(/^film:name=/,'') unless post['tags'].select{|t| t =~ /^film:name==/}.first.nil?
        entry.photos << photo
      end
      entry.save
    end
  end
end

def get_tumblr_posts(offset = 0, limit = 20)
  puts "Fetching posts #{offset + 1}-#{offset + limit}"
  posts = []
  response = HTTParty.get("http://api.tumblr.com/v2/blog/#{Rails.application.secrets.tumblr_domain}/posts/photo?api_key=#{Rails.application.secrets.tumblr_consumer_key}&filter=text&offset=#{offset}&limit=#{limit}")
  body = JSON.parse(response.body)
  posts << body['response']['posts']
  if body['response']['total_posts'] > offset + limit
    posts << get_tumblr_posts(offset + limit, limit)
  end
  posts.flatten
end
