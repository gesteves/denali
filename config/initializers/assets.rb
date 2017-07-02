# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path
# Rails.application.config.assets.paths << Emoji.images_path

# Add Yarn node_modules folder to the asset load path.
Rails.application.config.assets.paths << Rails.root.join('node_modules')

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
Rails.application.config.assets.precompile += %w(
  admin.css
  admin.js
  application.css
  application.js
  base.css
  entry_list.css
  entry.css
  preload.js
  components/entry_list.css
  components/entry.css
  components/error.css
  components/exif.css
  components/footer.css
  components/header.css
  components/header_minimal.css
  components/map.css
  components/pagination.css
  components/signin.css
  components/tags.css
  application/image_zoom.js
  application/infinite_scroll.js
  application/lazy_load.js
  application/map.js
)
