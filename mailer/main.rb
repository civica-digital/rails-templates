require 'open-uri'

def download(file, output: nil)
  output ||= file
  repo = 'https://raw.githubusercontent.com/civica-digital/rails-templates'
  branch = 'master'
  directory = 'mailer'
  url = "#{repo}/#{branch}/#{directory}/#{file}"

  render = open(url) do |input|
    data = input.binmode.read
    block_given? ? yield(data) : data
  end

  create_file output, render
end

say 'Configuring Mailer...', :yellow

if yes?('> Do you want to use Mailgun?', :green)
  gem 'mailgun-ruby'

  run 'bundle install'
end
