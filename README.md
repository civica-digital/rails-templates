# Rails templates
> Templates for Cívica Digital's projects

## Description
> Application templates are simple Ruby files containing DSL for adding
> gems/initializers etc. to your freshly created Rails project or an existing
> Rails project.
>
> http://edgeguides.rubyonrails.org/rails_application_templates.html

This repository holds several templates to encourage **convention over
configuration** in [Cívica Digital][civica-digital].

It has the following file structure:

(:warning: Example)
```bash
.
└── template          # Name of the template
   ├── README.md      #   Documentation
   ├── file-01.txt    #   Additional files that will be referenced/downloaded
   ├── file-02.yaml   #
   └── main.rb        #   Ruby file containing the application template
```

For example, there's a [Docker][docker] convention for Ruby on Rails projects,
so we add it to this repository:

```bash
.
└── docker
   ├── README.md
   ├── Dockerfile
   ├── docker-compose
   └── main.rb
```

## Usage
After initializing a project `rails new`, you can start adding the templates
with the following command:

```
bin/rails app:template LOCATION=...
```

Instead of remembering that command, you can add a `bash` function
to your terminal (i.e. `~/.bashrc`):

```bash
templ() {
  local usage='Usage: templ DIRECTORY'
  local reference='Reference: https://github.com/civica-digital/rails-templates'

  local repo='https://raw.githubusercontent.com/civica-digital/rails-templates'
  local branch='master'
  local directory=$1

  [[ -z ${directory} ]] && echo -e "${usage}\n${reference}" && return

  bin/rails app:template LOCATION=${repo}/${branch}/${directory}/main.rb
}
```

For more good vibes, you can have a _shell script_ under your `bin/` directory
in your application, `bin/templates`, as a log for the templates you used:

(:warning: Example)
```bash
#!/usr/bin/env
#
# Reference: https://github.com/civica-digital/rails-templates

templ docker
templ jenkins
templ mailer
templ simple-form
templ terraform
```

This way, you can just trigger `bin/templates` to update (re-run) every
template, and document the _components_/_modules_ your application is using
from the Cívica Digital conventions.

## Contributing
Feel free to send a **pull-request** to patch, add, or remove,
any of the templates.

Here are some tips to write **good** templates:

* Read the [documentation of Ruby on Rails templates][templates-doc]

* Write a README for your template, with information of why it's a convention
and useful links for reference (documentation, source, etc.)

* Use **initializers** instead of modifying `config/application.rb`,
referencing `Rails.configurations`

* Use **placeholders** like `{{app_name}}` and substitute them for the real value:
`gsub!('{{app_name}}', app_name)`

* Use **colors** to differentiate between questions and output:

```ruby
use_docker if yes?('> Do you want to use Docker?', :green)

def use_docker
  say 'Using Docker right now...', :yellow
  # ...
end
```

* If you need to use multiline strings, prefere the `heredoc` format:

```ruby
def print_message
  long_message = <<~TXT
    Numquam sed quae possimus minus est aperiam accusamus est
    Non ipsam architecto distinctio tempore molestiae
    Aut quo culpa quisquam nemo deserunt sed provident
    Laudantium repellendus odio aut cupiditate consequuntur
    Qui sed fugiat inventore quam itaque
  TXT

  say long_message, :yellow
end
```

* Write a `download` function like the one below to fetch documents from the
repository:

```ruby
require 'open-uri'  # <=== **THIS IS IMPORTANT**

# Fetch documents from the repository:
#
# Examples:
#
#   download('Dockerfile')
#   download('sidekiq.rb', output: 'config/initializers/sidekiq.rb')
#   download('database.yml') { |file| file.gsub!('{{app_name}}', app_name) }
#
def download(file, output: nil, &block)
  output ||= file
  repo = 'https://raw.githubusercontent.com/civica-digital/rails-templates'
  branch = 'master'
  directory = 'docker'  # <=== **CHANGE THIS**
  url = "#{repo}/#{branch}/#{directory}/#{file}"

  render = open(url) do |input|
    data = input.binmode.read
    if block_given? then block.call(data) else data end
  end

  create_file output, render
end
```

## Tests
To tests your templates simply call `templ` after a `rails new`, and verify
your template is doing what was intended.

## .railsrc
You can put a `~/.railsrc` with the following content, so every `rails new`
is ran with the respective flags:

```bash
--database=postgresql
--skip-coffee
--skip-test
--skip-system-test
--skip-bundle
```

## Roadmap
Visit the [issues][issues] section with the labels tagged as `roadmap`.

[templates-doc]: http://edgeguides.rubyonrails.org/rails_application_templates.html
[civica-digital]: https://civica.digital
[docker]: https://www.docker.com/community-edition
[issues]: https://github.com/civica-digital/rails-templates/issues
