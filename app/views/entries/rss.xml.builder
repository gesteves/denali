cache "rss/#{@photoblog.id}/#{@photoblog.updated_at.to_i}" do
  xml.instruct!
  xml.feed xmlns: 'http://www.w3.org/2005/Atom' do
    xml.id atom_tag(root_url, @photoblog.updated_at)
    xml.link rel: 'alternate', type: 'text/html', href: root_url
    xml.link rel: 'self', type: 'application/atom+xml', href: rss_url
    xml.title @photoblog.name
    xml.updated @photoblog.updated_at.utc.strftime('%FT%TZ')

    @entries.each do |e|
      cache "entry/rss/#{e.id}/#{e.updated_at.to_i}" do
        xml.entry do
          xml.id atom_tag(permalink_url(e), e.updated_at)
          xml.published e.published_at.utc.strftime('%FT%TZ')
          xml.updated e.updated_at.utc.strftime('%FT%TZ')
          xml.link rel: 'alternate', type: 'text/html', href: permalink_url(e)
          xml.title e.formatted_title
          body = ''
          e.photos.each do |p|
            body += image_tag p.url(2732)
            body += p.formatted_caption unless p.caption.blank?
          end
          body += e.formatted_body unless e.body.blank?
          if e.photos.count == 1
            photo = e.photos.first
            body += content_tag :p do
              exif = ''
              unless photo.make.blank? || photo.model.blank?
                exif += "Taken with #{article photo.make} #{camera photo.make, photo.model}"
                unless photo.film_make.blank? || photo.film_type.blank?
                  exif += "on #{film photo.film_make, photo.film_type}"
                end
              end
              unless photo.focal_length.blank?
                exif += " • #{photo.focal_length} mm focal length"
              end
              unless photo.exposure.blank? && photo.f_number.blank?
                 exif +=  " • "
                  unless photo.exposure.blank?
                    exif += exposure photo.exposure
                  end
                  unless photo.f_number.blank?
                    exif += " at f/#{aperture photo.f_number}"
                  end
              end
              unless photo.iso.blank?
                exif += " • ISO #{photo.iso}"
              end
              exif
            end
          end
          unless e.tags.blank?
            body += content_tag :p do
              tags = "Tagged "
              e.tags.each do |tag|
                tags += link_to "##{tag.name.downcase}", tag_url(tag.slug)
                tags += ' '
              end
              tags.html_safe
            end
          end
          xml.content body, type: 'html'
          xml.author do |author|
            author.name e.user.name
          end
        end
      end
    end
  end
end
