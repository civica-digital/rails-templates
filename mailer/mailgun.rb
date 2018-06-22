return unless Rails.env.production?

default_sender = "No Reply <no-reply@#{ENV['MAILGUN_DOMAIN']}>"

Rails.configuration.action_mailer.mailgun_settings = {
  api_key: ENV['MAILGUN_API_KEY'],
  domain: ENV['MAILGUN_DOMAIN']
}

Rails.configuration.action_mailer.delivery_method = :mailgun

Rails.configuration.action_mailer.asset_host = ENV.fetch('HOST') { '' }

Rails.config.mailer_sender = ENV.fetch('EMAIL_FROM') { default_sender }

Rails.config.action_mailer.default_url_options = {
  host: ENV.fetch('HOST') { '' },
}

