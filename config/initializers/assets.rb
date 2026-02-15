# Make mapbox-gl CSS available to the asset pipeline.
Rails.application.config.assets.paths << Rails.root.join("node_modules/mapbox-gl/dist")
