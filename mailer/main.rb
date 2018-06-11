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

say 'Configuring Mailer...', :yellow

if yes?('> Do you want to use Mailgun?', :green)
  gem 'mailgun-ruby'
  run 'bundle install'
  download 'mailgun.rb', output: 'config/initializers/mailer.rb'
end
