require 'open-uri'

def download(file, output: nil, &block)
  output ||= file
  repo = 'https://raw.githubusercontent.com/civica-digital/rails-templates'
  branch = 'master'
  directory = 'sidekiq'
  url = "#{repo}/#{branch}/#{directory}/#{file}"

  render = open(url) do |input|
    data = input.binmode.read
    if block_given? then block.call(data) else data end
  end

  create_file output, render
end

say 'Configuring Sidekiq...', :yellow

gem 'redis-rails'
gem 'sidekiq'

append_to_file 'Gemfile', redis_gem
append_to_file 'Gemfile', sidekiq_gem
download 'sidekiq.rb', output: 'config/initializers/sidekiq.rb'
