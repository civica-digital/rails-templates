return unless Rails.env.production?

host = ENV.fetch('HOST') { 'change-me-at-mailer.example.com' }

ActionMailer::Base.asset_host = host
ActionMailer::Base.default_url_options = { host: host }

ActionMailer::Base.delivery_method = :mailgun
ActionMailer::Base.mailgun_settings = {
  api_key: ENV['MAILGUN_API_KEY'],
  domain: ENV['MAILGUN_DOMAIN']
}
