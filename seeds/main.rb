require 'open-uri'

def download(file, output: nil, &block)
  output ||= file
  repo = 'https://raw.githubusercontent.com/civica-digital/rails-templates'
  branch = 'master'
  directory = 'seeds'
  url = "#{repo}/#{branch}/#{directory}/#{file}"

  render = open(url) do |input|
    data = input.binmode.read
    if block_given? then block.call(data) else data end
  end

  create_file output, render
end

say 'Configuring Seeds...', :yellow

Dir.mkdir('db/seeds') unless Dir.exist?('db/seeds')

gem 'activerecord-import', require: false
run 'bundle install'

download 'seeds.rb', output: 'db/seeds.rb'
download 'development.rb', output: 'db/seeds/development.rb' unless File.file?('db/seeds/development.rb')
download 'production.rb', output: 'db/seeds/production.rb' unless File.file?('db/seeds/production.rb')
