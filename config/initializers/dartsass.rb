Rails.application.config.dartsass.builds = {
  "application.scss" => "main.css",
  "admin.scss" => "admin.css",
  "print.scss" => "print.css"
}

Rails.application.config.dartsass.build_options = ["--load-path=node_modules"]
