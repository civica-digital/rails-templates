return unless Rails.env.production?

ActionMailer::Base.add_delivery_method :ses, AWS::SES::Base,
  access_key_id: ENV['AWS_SES_ACCESS_KEY'] || ENV['AWS_ACCESS_KEY'],
  secret_access_key: ENV['AWS_SES_SECRET_KEY'] || ENV['AWS_SECRET_KEY'],
  server: "email.#{ENV.fetch('AWS_REGION') { 'us-east-1' }}.amazonaws.com"

Rails.configuration.action_mailer.delivery_method = :ses
Rails.configuration.action_mailer.asset_host = ENV.fetch('HOST')

