# Rails templates
> _Templates_ usado en los proyectos de Cívica Digital

[![Maintainability](https://api.codeclimate.com/v1/badges/31d0ed2afea30ca89bfb/maintainability)](https://codeclimate.com/github/civica-digital/rails-templates/maintainability)

## Descripción
> Los _templates_ de aplicación son simples archivos de Ruby que contienen _DSL_ para agregar
> gemas, inicializadores, etc. a su proyecto de _Rails_ recientemente creado o
> ya avanzado.
>
> http://edgeguides.rubyonrails.org/rails_application_templates.html

Este repositorio contiene varias plantillas para fomentar la **convención sobre
configuración** en [Cívica Digital][civica-digital].


**Tiene la siguiente estructura de archivos:**

:warning: Ejemplo

```bash
.
└── template          # Nombre del template
   ├── README.md      #   Documentación
   ├── file-01.txt    #   Archivos adicionales que serán referenciados / descargados
   ├── file-02.yaml   #
   └── main.rb        #   Archivo Ruby que contiene el template de la aplicación
```

Por ejemplo, hay una convención [Docker][docker] para proyectos de Ruby on Rails,
así que lo agregamos a este repositorio:

```bash
.
└── docker
   ├── README.md
   ├── Dockerfile
   ├── docker-compose
   └── main.rb
```

## Incorporación

Para facilitar el uso vamos a agregar al `bash` una función que va a referenciar los _templates_ utilizando: `$ vim ~/.bashrc` y colocandolo al final del archivo.

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

Puede tener un script de shell en su `bin/` directorio en su aplicación, `bin/templates`, como un registro para las plantillas que utilizó:


:warning: Ejemplo

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

De esta forma, puede activar `bin/templates` para actualizar (volver a ejecutar) cada
plantilla, y documente los _components_/_modules_ que su aplicación está usando
de las convenciones de Cívica Digital.

## Uso

Después de inicializar un proyecto nuevo es decir después de correr `$ rails new proyect_name`, o en uno ya avanzado puede comenzar a agregar los _templates_ con el siguiente comando:

`$ templ nombre_template`


## Contribución

Siéntase libre de enviar un **pull-request** para parchar, agregar o eliminar,
cualquiera de las plantillas.

Aquí hay algunos consejos para escribir **buenas** plantillas:

* Lee la [documentación de  Ruby on Rails templates][templates-doc]

* Escriba un README para su plantilla, con información de por qué es una convención
y enlaces útiles para referencia (documentación, fuente, etc.)

* Use **initializers** en lugar de modificar `config/application.rb`,
haciendo referencia a `Rails.configurations`


* Use **placeholders** como `{{app_name}}` y sustitúyalos por el valor real:
`gsub!('{{app_name}}', app_name)`

* Use **colores** para diferenciar entre preguntas y resultados:

:warning: Ejemplo

```ruby
use_docker if yes?('> Do you want to use Docker?', :green)

def use_docker
  say 'Using Docker right now...', :yellow
  # ...
end
```

* Si necesita utilizar cadenas multilínea, prefiera el formato `heredoc`:

:warning: Ejemplo

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

* Escriba una función `download` como la que se encuentra abajo para buscar documentos del
repositorio:

:warning: Ejemplo

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

* Para agregar **VARIABLE DE AMBIENTE**, hacemos un seguimiento de ellos usando `git-crypt`,
puedes usar el siguiente _snipet_:

:warning: Ejemplo

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

* Para **alternar configuración**, puede usar la siguiente secuencia de comandos:

:warning: Ejemplo

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

Y el archivo debe tener el siguiente formato:

:warning: Ejemplo

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
Para probar sus _templates_ simplemente llame a `templ` y verifique que su plantilla está haciendo lo que se pretendía.


## .railsrc
Puede poner `~/.railsrc` con el siguiente contenido, por lo que cada `rails new`
se ejecuta con las banderas respectivas:

```bash
--database=postgresql
--skip-coffee
--skip-test
--skip-system-test
--skip-bundle
```

## :warning: Proyecto Ejemplo

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

## Contácto / problemas

Mantenemos la conversación del proyecto en nuestra página de [issues][issues] en GitHub.

Si tiene alguna otra pregunta, puede contactarnos por correo electrónico a <equipo@civica.digital>.


## Licencia

Bajo la Licencia GNU General Public License (GPL) 3.0. Lea el documento [Licencia][license] para más información

##### Powered by [Cívica Digital][civica-digital] y la comunidad, 2018.

[templates-doc]: http://edgeguides.rubyonrails.org/rails_application_templates.html
[civica-digital]: https://civica.digital
[docker]: https://www.docker.com/community-edition
[issues]: https://github.com/civica-digital/rails-templates/issues
[license]: https://www.gnu.org/licenses/gpl-3.0.html
