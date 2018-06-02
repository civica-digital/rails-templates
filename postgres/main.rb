require 'open-uri'

def download(file, output: nil, &block)
  output ||= file
  repo = 'https://raw.githubusercontent.com/civica-digital/rails-templates'
  branch = 'master'
  directory = 'postgres'
  url = "#{repo}/#{branch}/#{directory}/#{file}"

  render = open(url) do |input|
    data = input.binmode.read
    if block_given? then block.call(data) else data end
  end

  create_file output, render
end

say 'Configuring PostgreSQL...', :yellow

gem 'pg'
gem 'wait_pg'

download 'database.yml', output: 'config/database.yml' do |file|
  file.gsub('{{app_name}}', app_name)
end

if yes?('> Do you want to use PostGIS?', :green)
  gem 'activerecord-postgis-adapter'
  gsub_file 'config/database.yml', /postgresql/, 'postgis'
  run 'bundle install'
  rails_command 'db:gis:setup'
end

if yes?('> Do you want to use pg_search?', :green)
  gem 'pg_search'
end
