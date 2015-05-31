cache "entries/atom/#{photoblog.id}/#{photoblog.updated_at.to_i}" do
  atom_feed do |feed|
    feed.title photoblog.name
    feed.updated @entries.maximum(:updated_at)
    @entries.each do |entry|
      cache "entry/atom/#{entry.id}/#{entry.updated_at.to_i}" do
        feed.entry entry do |e|
          e.title entry.title
          body = ''
          entry.photos.each do |p|
            body += image_tag p.url(1280)
            body += p.formatted_caption unless p.caption.blank?
          end
          body = entry.formatted_body unless entry.body.blank?
          e.content body, type: 'html'
          e.url permalink(entry, { path_only: false })
          e.author do |author|
            author.name entry.user.name
          end
        end
      end
    end
  end
end
