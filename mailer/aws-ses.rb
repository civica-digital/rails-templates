return unless Rails.env.production?

host = ENV.fetch('HOST') { 'change-me-at-mailer.example.com' }
access_key = ENV['AWS_SES_ACCESS_KEY'] || ENV['AWS_ACCESS_KEY']
secret_key = ENV['AWS_SES_SECRET_KEY'] || ENV['AWS_SECRET_KEY']
region = ENV.fetch('AWS_REGION') { 'us-east-1' }

ActionMailer::Base.asset_host = host
ActionMailer::Base.default_url_options = { host: host }

ActionMailer::Base.add_delivery_method :ses, AWS::SES::Base,
  access_key_id: access_key,
  secret_access_key: secret_key,
  server: "email.#{region}.amazonaws.com"

ActionMailer::Base.delivery_method = :ses
