return unless Rails.env.production?

host = ENV.fetch('HOST') { 'change-me-at-mailer.example.com' }

ActionMailer::Base.asset_host = host
ActionMailer::Base.default_url_options = { host: host }

ActionMailer::Base.delivery_method = :smtp
ActionMailer::Base.smtp_settings = {
  user_name: ENV['SENDGRID_USERNAME'],
  password: ENV['SENDGRID_PASSWORD'],
  domain: host,
  address: 'smtp.sendgrid.net',
  port: 587,
  authentication: :plain,
  enable_starttls_auto: true
}
