def download(file, output: nil, &block)
  output ||= file
  repo = 'https://raw.githubusercontent.com/civica-digital/rails-templates'
  branch = 'master'
  directory = 'storage'
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

def file_encrypted?(filename)
  `git-crypt status -e`.include?(filename)
end

def add_env_var(variable, value=nil)
  environment_file = 'deploy/staging/provisions/environment'

  return unless File.exist?(environment_file)

  say("Error: You don't have git-crypt installed", :red) and
    return unless system('which git-crypt')

  say("Error: Your environment file is not encrypted", :red) and
    return unless file_encrypted?(environment_file)

  unless content_in_file?(variable, environment_file)
    value ||= ask("> #{variable}=", :green)
    append_to_file environment_file, "#{variable}=#{value}\n"
  end
end

if yes?('> Do you want to use AWS S3?', :green)
  gem 'carrierwave'
  gem 'fog-aws'
  run 'bundle install'

  download 'carrierwave-aws.rb', output: 'config/initializers/carrierwave.rb'

  add_env_var('AWS_S3_BUCKET')
  add_env_var('AWS_ACCESS_KEY')
  add_env_var('AWS_SECRET_KEY')

elsif yes?('> Do you want to use Google Cloud Storage?', :green)
  gem 'carrierwave'
  gem 'fog-google'
  gem 'google-api-client', '> 0.8.5', '< 0.9'
  gem 'mime-types'
  run 'bundle install'

  download 'carrierwave-google.rb', output: 'config/initializers/carrierwave.rb'

  add_env_var('GOOGLE_STORAGE_BUCKET')
  add_env_var('GOOGLE_STORAGE_ACCESS_KEY')
  add_env_var('GOOGLE_STORAGE_SECRET_KEY')
end
