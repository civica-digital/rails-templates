require 'open-uri'
require 'fileutils'

def download(file, output: nil, &block)
  output ||= file
  repo = 'https://raw.githubusercontent.com/civica-digital/rails-templates'
  branch = 'master'
  directory = 'base'
  url = "#{repo}/#{branch}/#{directory}/#{file}"

  render = open(url) do |input|
    data = input.binmode.read
    if block_given? then block.call(data) else data end
  end

  create_file output, render
end

def run_template(name)
  repo = 'https://raw.githubusercontent.com/civica-digital/rails-templates'
  branch = 'master'
  url = "#{repo}/#{branch}/#{name}/main.rb"

  if yes?("> Do you want to run #{name} template?", :green)
    run "rails app:template LOCATION=#{url}"
  end
end

def is_api?
  ApplicationController.ancestors.include?(ActionController::API)
end

say 'Adding default gitignore...', :yellow
download 'gitignore', output: '.gitignore'

say 'Configuring analyzers...', :yellow

gem_group :development do
  gem 'bullet'
  gem 'brakeman', require: false
  gem 'bundler-audit', require: false
  gem 'rails_best_practices', require: false
  gem 'reek', require: false
  gem 'rubocop', require: false
end

download 'bullet.rb', output: 'config/initializers/bullet.rb'
download 'rails_best_practices.yml', output: 'config/rails_best_practices.yml'
download 'reek', output: '.reek'
download 'rubucop.yml', output: '.rubocop.yml'

say 'Adding default development tools...', :yellow

gem_group :development, :test do
  gem 'pry-rails'
  gem 'active_record_query_trace'
end

say 'Modifying the default controller generator...', :yellow

Dir.exist?('lib/templates/rails/scaffold_controller') ||
  FileUtils.mkdir_p('lib/templates/rails/scaffold_controller')

download 'controller.rb', output: 'lib/templates/rails/scaffold_controller/controller.rb'

say 'Adding Rspec and Factory Bot', :yellow

gem_group :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
end

unless is_api?
  say 'Web development stuff', :yellow

  gem 'bootstrap', '~> 4.1.1'
  gem 'cocoon'
  gem 'haml-rails'
  gem 'high_voltage'
  gem 'jquery-rails'
  gem 'kaminari'
  gem 'simple_form'

  run 'bundle install'

  insert_into_file 'app/assets/javascripts/application.js',
                 "//= require bootstrap\n",
                 before: "//= require_tree ."

  insert_into_file 'app/assets/javascripts/application.js',
                 "//= require cocoon\n",
                 before: "//= require_tree ."

  insert_into_file 'app/assets/stylesheets/application.css',
                "\n\n@import 'bootstrap';",
                 after: '*/'

  Dir.exist?('app/views/pages') || Dir.mkdir('app/views/pages')

  run 'rails generate simple_form:install --bootstrap'
  run 'rails generate rspec:install'
  run 'HAML_RAILS_DELETE_ERB=true rake haml:erb2haml'
end

run_template :postgres
run_template :seeds
run_template :sidekiq
run_template :storage
run_template :scheduler
run_template :make
run_template :mailer
run_template :docker
run_template :deploy
