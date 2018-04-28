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

Respect the conventions.

## Roadmap
Visit the [issues][issues] section with the labels tagged as `roadmap`.

[civica-digital]: https://civica.digital
[docker]: https://www.docker.com/community-edition
[issues]: https://github.com/civica-digital/rails-templates/issues
