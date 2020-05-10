require 'graphql/client'
require 'graphql/client/http'

namespace :import do
  task :reset => %w{
    import:setup
    import:destroy
    import:blog
    import:entries
  }

  desc 'Set up GraphQL queries'
  task :setup => :environment do
    next if ENV['IMPORT_URL'].blank?
    HTTP = GraphQL::Client::HTTP.new(ENV['IMPORT_URL'])
    Schema = GraphQL::Client.load_schema(HTTP)
    Client = GraphQL::Client.new(schema: Schema, execute: HTTP)
    EntryFragment = Client.parse <<-'GRAPHQL'
      fragment on Entry {
        url
        slug
        title
        body
        instagramLocationName
        status
        publishedAt
        modifiedAt
        tags {
          name
        }
        photos {
          filename
          originalUrl
          altText
          focalX
          focalY
          camera {
            slug
            make
            model
            name
          }
          lens {
            slug
            make
            model
            name
          }
          film {
            slug
            make
            model
            name
          }
        }
        user {
          name
          firstName
          lastName
        }
      }
    GRAPHQL
    Queries = Client.parse <<-'GRAPHQL'
    query ImportBlog {
      blog {
        name
        tagLine
        about
        copyright
        email
        facebook
        flickr
        instagram
        twitter
        tumblr
        postsPerPage
        timeZone
        metaDescription
        mapStyle
        headerLogoSvg
        showSearch
        showRelatedEntries
      }
    }

    query ImportEntries($page: Int!, $count: Int!) {
      entries(page: $page, count: $count) {
        ...EntryFragment
      }
    }

    query ImportEntry($url: String!) {
      entry(url: $url) {
        ...EntryFragment
      }
    }
    GRAPHQL
  end

  desc 'Destroy existing content'
  task :destroy => :environment do
    next if ENV['IMPORT_URL'].blank?

    puts "Destroying blogs…"
    Blog.destroy_all
  end

  desc 'Import blog content'
  task :blog => :environment do
    next if ENV['IMPORT_URL'].blank?
    puts "\nFetching import data for blog…"

    response = Client.query(Queries::ImportBlog)
    data = response.data.to_h.with_indifferent_access

    import_blog(data[:blog])
  end

  desc 'Import a number of entries'
  task :entries => :environment do
    next if ENV['IMPORT_URL'].blank?
    per_page = 10
    total_entries = (ENV['COUNT'] || 100).to_f
    puts "Fetching #{total_entries.to_i} entries in batches of #{per_page}…"

    total_pages = (total_entries / per_page.to_f).ceil
    remaining_entries = total_entries

    total_pages.times do |page|
      count = [remaining_entries, per_page].min
      puts "\nFetching batch of #{count.to_i} entries…"
      response = Client.query(Queries::ImportEntries, variables: { page: page + 1, count: count })
      data = response.data.to_h.with_indifferent_access
      data[:entries].each { |entry| import_entry(entry) }
      remaining_entries = remaining_entries - per_page
    end

  end

  desc 'Import an entry'
  task :entry => [:environment, :setup] do
    next if ENV['IMPORT_URL'].blank? || ENV['ENTRY_URL'].blank?

    puts "Fetching data for entry “#{ENV['ENTRY_URL']}”…"
    response = Client.query(Queries::ImportEntry, variables: { url: ENV['ENTRY_URL'] })
    data = response.data.to_h.with_indifferent_access
    import_entry(data[:entry])
  end
end

def import_blog(data)
  return if data.blank?
  blog = if Blog.first.present?
    puts "Updating blog"
    Blog.first
  else
    puts "Creating new blog"
    Blog.new
  end

  blog.about = data[:about]
  blog.copyright = data[:copyright]
  blog.email = data[:email]
  blog.facebook = data[:facebook]
  blog.flickr = data[:flickr]
  blog.header_logo_svg = data[:headerLogoSvg]
  blog.instagram = data[:instagram]
  blog.map_style = data[:mapStyle]
  blog.meta_description = data[:metaDescription]
  blog.name = data[:name]
  blog.posts_per_page = data[:postsPerPage]
  blog.show_related_entries = data[:showRelatedEntries]
  blog.show_search = data[:showSearch]
  blog.tag_line = data[:tagLine]
  blog.time_zone = data[:timeZone]
  blog.tumblr = data[:tumblr]
  blog.twitter = data[:twitter]
  blog.save!
  puts "Saved changes to “#{blog.name}”"
end

def import_entry(data)
  blog = Blog.first
  return if blog.blank? || data.blank?
  puts "Importing entry “#{data[:url]}”"
  begin
    entry = Entry.new(
      blog: blog,
      user: User.find_or_create_by!(name: data[:user][:name], first_name: data[:user][:firstName], last_name: data[:user][:lastName]),
      slug: data[:slug],
      title: data[:title],
      body: data[:body],
      status: data[:status],
      post_to_instagram: false,
      post_to_twitter: false,
      post_to_facebook: false,
      post_to_tumblr: false,
      post_to_flickr: false,
      post_to_flickr_groups: false
    )
    entry.published_at = Time.parse(data[:publishedAt]) if data[:publishedAt].present?
    entry.modified_at = Time.parse(data[:modifiedAt]) if data[:modifiedAt].present?
    entry.instagram_location_list = data[:instagramLocationName]
    entry.tag_list = data[:tags].map { |t| t[:name] }.join(', ')
    entry.photos = data[:photos].map do |p|
      photo = Photo.new(alt_text: p[:altText], focal_x: p[:focalX], focal_y: p[:focalY])
      file_path = open(p[:originalUrl]).path
      photo.image.attach(io: File.open(file_path), filename: p[:filename])
      photo.camera = Camera.find_or_initialize_by(slug: p[:camera][:slug], make: p[:camera][:make], model: p[:camera][:model], display_name: p[:camera][:name]) if p[:camera].present?
      photo.lens = Lens.find_or_initialize_by(slug: p[:lens][:slug], make: p[:lens][:make], model: p[:lens][:model], display_name: p[:lens][:name]) if p[:lens].present?
      photo.film = Film.find_or_initialize_by(slug: p[:film][:slug], make: p[:film][:make], model: p[:film][:model], display_name: p[:film][:name]) if p[:film].present?
      photo
    end
    entry.status = 'published'
    entry.save!
  rescue StandardError => e
    puts "Failed to save entry: #{e}"
  end
end
