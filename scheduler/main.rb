require 'open-uri'

def download(file, output: nil, &block)
  output ||= file
  repo = 'https://raw.githubusercontent.com/civica-digital/rails-templates'
  branch = 'master'
  directory = 'scheduler'
  url = "#{repo}/#{branch}/#{directory}/#{file}"

  render = open(url) do |input|
    data = input.binmode.read
    if block_given? then block.call(data) else data end
  end

  create_file output, render
end

say 'Configuring Scheduler...', :yellow

download 'ofelia', output: 'bin/ofelia'
chmod 'bin/ofelia', 0775

download 'config.ini', output: 'config/ofelia.ini'

if File.file?('docker-compose.yml')
  scheduler_service = <<~YML
    scheduler:
      <<: *web
      command: ofelia daemon --config /usr/src/config/ofelia.ini
  YML

  insert_into_file 'docker-compose.yml',
                   scheduler_service,
                   before: "volumes:\n"
end
