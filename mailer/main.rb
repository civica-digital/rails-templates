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

environment_file = 'deploy/staging/provisions/environment'

say 'Configuring Mailer...', :yellow

if yes?('> Do you want to use Mailgun?', :green)
  gem 'mailgun-ruby'
  run 'bundle install'
  download 'mailgun.rb', output: 'config/initializers/mailer.rb'

  if File.exist?(environment_file) \
      && !content_in_file?('MAILGUN_API_KEY=', environment_file)

    say('Configuring Mailgun...', :yellow)

    api_key = ask('> MAILGUN_API_KEY=', :green)
    domain = ask('> MAILGUN_DOMAIN=', :green)

    append_to_file environment_file, "MAILGUN_API_KEY=#{api_key}\n"
    append_to_file environment_file, "MAILGUN_DOMAIN=#{domain}\n"
  end

elsif yes?('> Do you want to use AWS SES?', :green)
  gem 'aws-ses', require: 'aws/ses'
  run 'bundle install'
  download 'aws-ses.rb', output: 'config/initializers/mailer.rb'
end


if defined?(Devise)
  say('Configuring Devise mailer...', :yellow)

  gsub_file 'config/initializers/devise.rb',
            /\s*config.mailer_sender.*/,
            "  config.mailer_sender = ENV.fetch('EMAIL_FROM') { 'changeme@example.com' }\n"
end
