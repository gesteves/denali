require 'psych'

yaml_content = File.read(Rails.root.join('config/search.yml'))
SEARCH_CONFIG = Psych.safe_load(yaml_content, permitted_classes: [], permitted_symbols: [], aliases: true).with_indifferent_access
