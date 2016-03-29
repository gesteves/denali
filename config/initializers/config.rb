app_config = Rails.application.config_for(:config)

Rails.application.config.site = app_config['site']
Rails.application.config.social = app_config['social']
