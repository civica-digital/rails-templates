require 'open-uri'

def download(file, output: nil, &block)
  output ||= file
  repo = 'https://raw.githubusercontent.com/civica-digital/rails-templates'
  branch = 'master'
  directory = 'sidekiq'
  url = "#{repo}/#{branch}/#{directory}/#{file}"

  render = open(url) do |input|
    return input.binmode.read unless block_given?

    block.call(input.binmode.read)
  end

  create_file output, render
end

gem 'redis-rails'
gem 'sidekiq'
download 'sidekiq.rb', output: 'config/initializers/sidekiq'
