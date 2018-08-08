# Rails templates
> Templates for Cívica Digital's projects

## Description
> Los _templates_ de aplicación son simples archivos de Ruby que contienen _DSL_ para agregar
> gemas, initializadores, etc. a su proyecto de _Rails_ recientemente creado o
> ya avanzado.
>
> http://edgeguides.rubyonrails.org/rails_application_templates.html

This repository holds several templates to encourage **convention over
configuration** in [Cívica Digital][civica-digital].


**It has the following file structure:**

:warning: Example

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

## Integration

To facilitate the use we will add a `bash` the next function that will reference the _templates_ using: `$vim ~/.bashrc` and put it at the end of the file.

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


:warning: Example

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

## Usage

After initializing a new project `$rails new proyect_name`, or in an advanced one you can start adding the _templates_ with the following command:

`$templ nombre_template`


## Contributing

Feel free to send a **pull-request** to patch, add, or remove, any of the templates.

Here are some tips to write **good** templates:

* Read the [documentation of Ruby on Rails templates][templates-doc]

* Write a README for your template, with information of why it's a convention
and useful links for reference (documentation, source, etc.)

* Use **initializers** instead of modifying `config/application.rb`,
referencing `Rails.configurations`

* Use **placeholders** like `{{app_name}}` and substitute them for the real value:
`gsub!('{{app_name}}', app_name)`

* Use **colors** to differentiate between questions and output:

:warning: Example

```ruby
use_docker if yes?('> Do you want to use Docker?', :green)

def use_docker
  say 'Using Docker right now...', :yellow
  # ...
end
```

*  If you need to use multiline strings, prefere the `heredoc` format:

:warning: Example

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

:warning: Example

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

* To add an **ENVIRONMENT VARIABLE**, we keep track of them using `git-crypt`,
you can use the following snipet:

:warning: Example

```ruby
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

# Example:
#   add_env_var('ROLLBAR_ACCESS_TOKEN')
#   add_env_var('ROLLBAR_ENV', 'staging')
```

* To **toggle settings**, you can use the following script:

:warning: Example

```ruby
def toggle_setting(name, file)
  if yield
    file.gsub!("##{name}", '')
  else
    file.gsub!(/##{name}.*\n/, '')
  end
end

# Example:
#   toggle_setting(:mongo, file) { defined?(Mongo) }
```

And the file should have the following format:

:warning: Example

```bash
version: '3'

services:
  db:
    image: postgres:10.3-alpine
    volumes:
      - db:/var/lib/postgresql/data
#mongo
#mongo  mongo:
#mongo    image: mongo:3.6.4
#mongo    volumes:
#mongo      - mongo:/db/data

volumes:
  db:
#mongo  mongo:
  gems:
```

## Tests

To tests your _templates_ simply call `templ template_name`  and verify your template is doing what was intended.

## .railsrc
You can put a `~/.railsrc` with the following content, so every `rails new` is ran with the respective flags:

```bash
--database=postgresql
--skip-coffee
--skip-test
--skip-system-test
--skip-bundle
```

## :warning: Project Example

```bash
#!/usr/bin/env bash

rails new \
  --database=postgresql \
  --skip-coffee \
  --skip-test \
  --skip-system-test \
  --skip-bundle \
  --skip-action-cable \
  myapp

cd myapp;        bundle install; git add -A; git commit -m "Initial commit"
templ postgres;  bundle install; git add -A; git commit -m "Add PostgreSQL template"
templ docker;    bundle install; git add -A; git commit -m "Add Docker template"
templ make;      bundle install; git add -A; git commit -m "Add Makefile"
```

## Contact us / Problems

We keep the proyect conversation in our [issues][issues] page in GitHub.

If you have any other questions, you can contact us by mail at <equipo@civica.digital>.


## License

Licensed under the GNU General Public License (GPL) 3.0. Read the document [Licencia][license] for more information

##### Powered by [Cívica Digital][civica-digital] y the community, 2018.

[templates-doc]: http://edgeguides.rubyonrails.org/rails_application_templates.html
[civica-digital]: https://civica.digital
[docker]: https://www.docker.com/community-edition
[issues]: https://github.com/civica-digital/rails-templates/issues
[license]: https://www.gnu.org/licenses/gpl-3.0.html
