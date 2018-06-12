return unless Rails.env.production?

Rails.configuration.action_mailer.mailgun_settings = {
  api_key: ENV['MAILGUN_APIKEY'],
  domain: ENV['MAILGUN_DOMAIN']
}

Rails.configuration.action_mailer.delivery_method = :mailgun
Rails.configuration.action_mailer.asset_host = ENV.fetch('HOST')
