json.short_name @photoblog.name.split(/[\s-]/).map { |s| s.first.upcase }.join
json.name @photoblog.name
json.start_url root_path
json.theme_color '#BF0222'
json.display 'browser'
json.icons @icons, :sizes, :src, :type
