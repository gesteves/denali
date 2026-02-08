# Be sure to restart your server when you modify this file.

# Add Yarn node_modules folder to the asset load path.
Rails.application.config.assets.paths << Rails.root.join('node_modules')

# Precompile mapbox-gl CSS from node_modules.
Rails.application.config.assets.precompile += %w[ mapbox-gl/dist/mapbox-gl.css ]
