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

say 'Configuring Jenkins...', :yellow

download 'Jenkinsfile' do |file|
  file.gsub('{{app_name}}', app_name.gsub('_', '-'))
end

say 'Creating deploy directory...', :yellow

Dir.mkdir('deploy') unless Dir.exist?('deploy')

say 'Setting up the deploy for staging...', :yellow

Dir.mkdir('deploy/staging') unless Dir.exist?('deploy/staging')
Dir.mkdir('deploy/staging/scripts') unless Dir.exist?('deploy/staging/scripts')
Dir.mkdir('deploy/staging/provisions') unless Dir.exist?('deploy/staging/provisions')

download 'setup-server.sh', output: 'deploy/staging/scripts/setup-server.sh'
download 'update-container.sh', output: 'deploy/staging/scripts/update-container.sh'

download 'azure.tf', output: 'deploy/staging/main.tf' do |file|
  file.gsub('{{app_name}}', app_name.gsub('_', '-'))
end

download 'environment', output: 'deploy/staging/provisions/environment' do |file|
  file.gsub!('{{app_name}}', app_name.gsub('_', '-'))
  file.gsub!('{{db_name}}', "#{app_name}_production")
  file.gsub!('{{secret_key_base}}', "#{SecureRandom.hex(64)}")
end

download 'traefik.toml', output: 'deploy/staging/provisions/traefik.toml' do |file|
  file.gsub('{{app_name}}', app_name.gsub('_', '-'))
end

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
