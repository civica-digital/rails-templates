require 'open-uri'

def download(file, output: nil, &block)
  output ||= file
  repo = 'https://raw.githubusercontent.com/civica-digital/rails-templates'
  branch = 'master'
  directory = 'mailer'
  url = "#{repo}/#{branch}/#{directory}/#{file}"

  render = open(url) do |input|
    data = input.binmode.read
    if block_given? then block.call(data) else data end
  end

  create_file output, render
end

def content_in_file?(content, file)
  File.read(file).include?(content)
end

def add_env_var(variable)
  environment_file = 'deploy/staging/provisions/environment'

  return unless File.exist?(environment_file)

  unless content_in_file?(variable, environment_file)
    email_from = ask("> #{variable}=", :green)
    append_to_file environment_file, "#{variable}=#{email_from}\n"
  end
end

say 'Configuring Mailer...', :yellow

if yes?('> Do you want to use Mailgun?', :green)
  gem 'mailgun-ruby'
  run 'bundle install'
  download 'mailgun.rb', output: 'config/initializers/mailer.rb'

  say('Configuring Mailgun...', :yellow)

  add_env_var('MAILGUN_API_KEY')
  add_env_var('MAILGUN_DOMAIN')

elsif yes?('> Do you want to use AWS SES?', :green)
  gem 'aws-ses', require: 'aws/ses'
  run 'bundle install'
  download 'aws-ses.rb', output: 'config/initializers/mailer.rb'
end


if defined?(Devise)
  say('Configuring Devise mailer...', :yellow)

  gsub_file 'config/initializers/devise.rb',
            /  config.mailer_sender.*/,
            "  config.mailer_sender = ENV.fetch('EMAIL_FROM') { 'changeme@example.com' }\n"

  add_env_var('EMAIL_FROM')
end
