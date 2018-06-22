require 'open-uri'

def download(file, output: nil, &block)
  output ||= file
  repo = 'https://raw.githubusercontent.com/civica-digital/rails-templates'
  branch = 'master'
  directory = 'deploy'
  url = "#{repo}/#{branch}/#{directory}/#{file}"

  render = open(url) do |input|
    data = input.binmode.read
    if block_given? then block.call(data) else data end
  end

  create_file output, render
end

def toggle_setting(name, file)
  if yield
    file.gsub!("##{name}--", '')
  else
    file.gsub!(/##{name}.*\n/, '')
  end
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

def jenkins
  say 'Configuring Jenkins...', :yellow

  download 'Jenkinsfile' do |file|
    file.gsub('{{app_name}}', app_name.gsub('_', '-'))
  end
end

def setup_deploy_directory
  say 'Creating deploy directory...', :yellow

  Dir.mkdir('deploy') unless Dir.exist?('deploy')

  say 'Setting up the deploy for staging...', :yellow

  Dir.mkdir('deploy/staging') unless Dir.exist?('deploy/staging')
  Dir.mkdir('deploy/staging/scripts') unless Dir.exist?('deploy/staging/scripts')
  Dir.mkdir('deploy/staging/provisions') unless Dir.exist?('deploy/staging/provisions')
end

def scripts
  scripts_dir = 'deploy/staging/scripts'
  image = "centos" # ubuntu

  download "#{image}-setup-server.sh", output: "#{scripts_dir}/setup-server.sh"
  download 'update-container.sh', output: "#{scripts_dir}/update-container.sh"
end

def terraform
  download 'azure.tf', output: 'deploy/staging/main.tf' do |file|
    file.gsub!('{{app_name}}', app_name.gsub('_', '-'))

    toggle_setting(:s3, file) { defined?(Fog::AWS) }
    toggle_setting(:ses, file) { defined?(AWS::SES) }
  end
end

def provisions
  directory = 'deploy/staging/provisions'

  # Traefik
  download 'traefik.toml', output: "#{directory}/traefik.toml" do |file|
    file.gsub('{{app_name}}', app_name.gsub('_', '-'))
  end

  # Environment
  download 'environment', output: "#{directory}/environment" do |file|
    file.gsub!('{{app_name}}', app_name.gsub('_', '-'))
    file.gsub!('{{db_name}}', "#{app_name}_production")
    file.gsub!('{{secret_key_base}}', "#{SecureRandom.hex(64)}")
  end unless File.exist?("#{directory}/environment")

  # Docker Compose
  download 'docker-compose.yml', output: "#{directory}/docker-compose.yml" do |file|
    say('Configuring Docker Compose for staging...', :yellow)

    db_user     = "#{SecureRandom.alphanumeric(8)}"
    db_password = "#{SecureRandom.urlsafe_base64(64)}"
    db_name     = "#{app_name}_production"
    db_url      = "postgresql://#{db_user}:#{db_password}@db/#{db_name}"

    add_env_var('DATABASE_URL', db_url)

    file.gsub!('{{db_user}}',     db_user)
    file.gsub!('{{db_password}}', db_password)
    file.gsub!('{{db_name}}',     db_name)
    file.gsub!('{{app_name}}',    app_name.gsub('_', '-'))
  end unless File.exist?("#{directory}/docker-compose.yml")

  # New Relic
  add_env_var('NEW_RELIC_LICENSE_KEY')
  add_env_var('NEW_RELIC_ENV', 'staging')

  # Rollbar
  add_env_var('ROLLBAR_ACCESS_TOKEN')
  add_env_var('ROLLBAR_ENV', 'staging')
end

def git_crypt
  say 'Configuring git-crypt...', :yellow

  team_members = %w(
    abisosa
    fercreek
    mikesaurio
    mroutis
    rafaelcr
    ricalanis
    civica_ci
  )

  `git-crypt init`
  team_members.each { |user| `curl https://keybase.io/#{user}/pgp_keys.asc | gpg --import` }
  team_members.each { |user| `git-crypt add-gpg-user --trusted #{user[0..2]}` }

  # Add civica_ci (jenkins) user
  `git-crypt add-gpg-user --trusted admin@civica.digital`

  gitattributes = <<~CONF
  **/provisions/** filter=git-crypt diff=git-crypt
  CONF

  create_file '.gitattributes', gitattributes
end

def main
  jenkins
  setup_deploy_directory
  scripts
  terraform
  provisions
  git_crypt
end

main
