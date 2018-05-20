json.lang 'en'
json.name @photoblog.name
json.short_name @photoblog.name.split(/[\s-]/).map { |s| s.first.upcase }.join
json.start_url root_path
json.theme_color '#BF0222'
json.background_color '#FFFFFF'
json.display 'minimal-ui'
json.icons @icons, :sizes, :src, :type
