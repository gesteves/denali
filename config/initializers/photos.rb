require 'psych'

yaml_content = File.read(Rails.root.join('config/photos.yml'))
PHOTOS = Psych.safe_load(yaml_content, aliases: true).with_indifferent_access
