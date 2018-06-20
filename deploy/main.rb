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

def toggle_service(name, file)
  if yield
    file.gsub!("##{name}--", '')
  else
    file.gsub!(/##{name}.*\n/, '')
  end
end

def content_in_file?(content, file)
  File.read(file).include?(content)
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

  download 'setup-server.sh', output: "#{scripts_dir}/setup-server.sh"
  download 'update-container.sh', output: "#{scripts_dir}/update-container.sh"
end

def terraform
  download 'azure.tf', output: 'deploy/staging/main.tf' do |file|
    file.gsub!('{{app_name}}', app_name.gsub('_', '-'))

    toggle_service(:s3, file) { defined?(Fog::AWS) }
    toggle_service(:ses, file) { defined?(AWS::SES) }
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

    append_to_file "#{directory}/environment", "DATABASE_URL=#{db_url}\n"

    file.gsub!('{{db_user}}',     db_user)
    file.gsub!('{{db_password}}', db_password)
    file.gsub!('{{db_name}}',     db_name)
    file.gsub!('{{app_name}}',    app_name.gsub('_', '-'))
  end unless File.exist?("#{directory}/docker-compose.yml")

  # New Relic
  unless content_in_file?('NEW_RELIC_LICENSE_KEY=', "#{directory}/environment")
    say('Configuring New Relic...', :yellow)

    license_key = ask('> NEW_RELIC_LICENSE_KEY=', :green)

    append_to_file "#{directory}/environment", "NEW_RELIC_LICENSE_KEY=#{license_key}\n"
    append_to_file "#{directory}/environment", "NEW_RELIC_ENV=staging\n"
  end

  # Rollbar
  unless content_in_file?('ROLLBAR_ACCESS_TOKEN=', "#{directory}/environment")
    say('Configuring Rollbar...', :yellow)

    token = ask('> ROLLBAR_ACCESS_TOKEN=', :green)

    append_to_file "#{directory}/environment", "ROLLBAR_ACCESS_TOKEN=#{token}\n"
    append_to_file "#{directory}/environment", "ROLLBAR_ENV=staging\n"
  end
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
  )

  `git-crypt init`
  team_members.each { |user| `curl https://keybase.io/#{user}/pgp_keys.asc | gpg --import` }
  team_members.each { |user| `git-crypt add-gpg-user --trusted #{user[0..2]}` }

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
