require 'open-uri'

def download(file, output: nil, &block)
  output ||= file
  repo = 'https://raw.githubusercontent.com/civica-digital/rails-templates'
  branch = 'master'
  directory = 'docker'
  url = "#{repo}/#{branch}/#{directory}/#{file}"

  render = open(url) do |input|
    data = input.binmode.read
    if block_given? then block.call(data) else data end
  end

  create_file output, render
end

say 'Configuring Docker...', :yellow

download 'Dockerfile'
download 'Dockerfile.dev'
download '.dockerignore'
download 'docker-compose.yml' do |file|
  file.gsub!('{{app_name}}', app_name.gsub('_', '-'))

  if defined?(Mongo)
    file.gsub!('#mongo', '')
  else
    file.gsub!(/#mongo.*\n/, '')
  end

  if defined?(Sidekiq)
    file.gsub!('#sidekiq', '')
  else
    file.gsub!(/#sidekiq.*\n/, '')
  end

  if File.file?('config/ofelia.ini')
    file.gsub!('#scheduler', '')
  else
    file.gsub!(/#scheduler.*\n/, '')
  end
end

download 'web_console.rb', output: 'config/initializers/web_console.rb'
