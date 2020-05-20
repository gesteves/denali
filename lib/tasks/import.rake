namespace :blog do
  task :import => %w{
    import:blog
    import:entries
  }

  namespace :import do
    task :reset => %w{
      import:destroy
      import:blog
      import:entries
    }

    desc 'Destroy existing content'
    task :destroy => :environment do
      next if Rails.env.production? || ENV['IMPORT_ENDPOINT'].blank?

      puts "Removing existing entries…\n\n"
      Entry.destroy_all
    end

    desc 'Import blog content'
    task :blog => :environment do
      next if Rails.env.production? || ENV['IMPORT_ENDPOINT'].blank?
      puts "Fetching import data for blog…"

      response = graphql_query(operation_name: 'ImportBlog')
      import_blog(response.dig(:data, :blog))
    end

    desc 'Import a number of entries'
    task :entries => :environment do
      next if Rails.env.production? || ENV['IMPORT_ENDPOINT'].blank?
      per_page = 100
      total_entries = (ENV['COUNT'] || 100).to_f
      puts "\nFetching #{total_entries.to_i} entries in batches of #{per_page}…"

      total_pages = (total_entries / per_page.to_f).ceil
      remaining_entries = total_entries

      total_pages.times do |page|
        count = [remaining_entries, per_page].min
        response = graphql_query(operation_name: 'ImportEntries', variables: { page: page + 1, count: count })
        response.dig(:data, :entries)&.each { |entry| import_entry(entry) }
        remaining_entries = remaining_entries - per_page
      end

    end

    desc 'Import an entry'
    task :entry => :environment do
      next if Rails.env.production? || ENV['IMPORT_ENDPOINT'].blank? || ENV['ENTRY_URL'].blank?

      puts "Fetching data for entry “#{ENV['ENTRY_URL']}”…"

      response = graphql_query(operation_name: 'ImportEntry', variables: { url: ENV['ENTRY_URL'] })
      import_entry(response.dig(:data, :entry))
    end
  end
end

def graphql_query(operation_name:, variables: nil)
  return if Rails.env.production? || ENV['IMPORT_ENDPOINT'].blank?
  query = <<~GRAPHQL
    fragment entryFragment on Entry {
      url
      slug
      title
      body
      status
      publishedAt
      modifiedAt
      previewHash
      tags {
        name
      }
      photos {
        urls(widths: [3360])
        filename
        altText
        focalX
        focalY
        aperture
        exposure
        focalLength
        iso
        latitude
        longitude
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
        ...entryFragment
      }
    }

    query ImportEntry($url: String!) {
      entry(url: $url) {
        ...entryFragment
      }
    }
  GRAPHQL

  body = {
    query: query,
    variables: variables,
    operationName: operation_name
  }.compact
  begin
    response = HTTParty.post(ENV['IMPORT_ENDPOINT'], body: body.to_json, headers: { 'Content-Type': 'application/json' })
    JSON.parse(response.body).with_indifferent_access
  rescue StandardError
    nil
  end
end

def import_blog(data)
  return if Rails.env.production? || data.blank?
  blog = if Blog.first.present?
    Blog.first
  else
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
  puts "Saved changes to blog “#{blog.name}”"
end

def import_entry(data)
  return if Rails.env.production? || data.blank?
  blog = Blog.first
  return if blog.blank?
  puts "  Importing entry “#{data[:url]}”"
  begin
    entry = Entry.find_or_initialize_by(preview_hash: data[:previewHash])
    if entry.persisted?
      puts "    Entry already exists, skipping…"
      return
    end
    entry.blog = blog
    entry.user = User.find_or_create_by!(name: data[:user][:name], first_name: data[:user][:firstName], last_name: data[:user][:lastName])
    entry.slug = data[:slug]
    entry.title = data[:title]
    entry.body = data[:body]
    entry.status = data[:status]
    entry.post_to_instagram = false
    entry.post_to_twitter = false
    entry.post_to_facebook = false
    entry.post_to_tumblr = false
    entry.post_to_flickr = false
    entry.post_to_flickr_groups = false
    entry.published_at = Time.parse(data[:publishedAt]) if data[:publishedAt].present?
    entry.modified_at = Time.parse(data[:modifiedAt]) if data[:modifiedAt].present?
    entry.tag_list = data[:tags].map { |t| t[:name] }.join(', ')
    entry.photos = data[:photos].map do |p|
      photo = Photo.new(alt_text: p[:altText], focal_x: p[:focalX], focal_y: p[:focalY], f_number: p[:aperture], focal_length: p[:focalLength], iso: p[:iso], exposure: p[:exposure], latitude: p[:latitude], longitude: p[:longitude])
      file_path = open(p[:urls][0]).path
      photo.image.attach(io: File.open(file_path), filename: p[:filename])
      photo.camera = Camera.find_or_initialize_by(slug: p[:camera][:slug], make: p[:camera][:make], model: p[:camera][:model], display_name: p[:camera][:name]) if p[:camera].present?
      photo.lens = Lens.find_or_initialize_by(slug: p[:lens][:slug], make: p[:lens][:make], model: p[:lens][:model], display_name: p[:lens][:name]) if p[:lens].present?
      photo.film = Film.find_or_initialize_by(slug: p[:film][:slug], make: p[:film][:make], model: p[:film][:model], display_name: p[:film][:name]) if p[:film].present?
      photo
    end
    entry.status = 'published'
    entry.save!
    puts "    Entry saved."
  rescue StandardError => e
    puts "    Failed to save entry: #{e}"
  end
end
