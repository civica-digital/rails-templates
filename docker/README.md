# Docker
> Docker configuration

Site: https://docker.com/
Source: https://github.com/moby/moby
Documentation: https://docs.docker.com/

## Usage

Open Source database with full text search support and geographical functions.

------------------------------------------------------------

:warning: Outdated

### Introducción

Las decisiones que se están tomando en las empresas de software apuntan a una arquitectura descentralizada, que promueve la **fiabilidad** y **escalabilidad** de los sistemas. Herramientas como **Docker**
facilitan generar una infrastructura con estas propiedades.

Cuando desarrollas con Docker, tienes que pensar en los _procesos / servicios_ que tu
aplicación necesita, por ejemplo: una base de datos, un servidor de archivos, una API,
un sistema de caché, colas de prioridades, etc; y crear una _imagen_ para cada uno que
defina el ambiente (mínimo) necesario para correr.

Hay _imágenes_ oficiales de algunos servicios, es decir, una _imagen_ autorizada por sus
desarrolladores. Éstas las puedes encontrar en el _registro_ de Docker:
[Docker Hub](https://hub.docker.com/).

A partir de _imágenes_ creas _contenedores_, que representan un **proceso** corriendo en el
ambiente definido por la _imagen_.
Si se quiere hacer un símil con el paradigma orientado a objetos:
```
clases -> imágenes
objetos -> contenedores
```
Al igual que los objetos, los _contenedores_ parten de un ente que define su comportamiento.

El siguiente es un _Dockerfile_ ejemplo de una aplicación en Ruby on Rails corriendo en producción:
```dockerfile
FROM ruby:2.3.1

RUN apt-get update -qq && apt-get install -y \
  build-essential \
  libpq-dev \
  nodejs

RUN ln -s /usr/bin/nodejs /usr/bin/node

RUN mkdir /app
WORKDIR /app

COPY Gemfile* /app/

ENV RAILS_ENV production
ENV NODE_ENV production

RUN bundle install --deployment --without test development

COPY . /app

ENV SECRET_KEY_BASE $(openssl rand -base64 32)
RUN rake assets:precompile

EXPOSE 3000

CMD ["rails", "server", "-b", "0.0.0.0"]
```

Una forma de describir y manejar los _contenedores_ que necesita tu aplicación, es usando
[Docker Compose](https://docs.docker.com/compose/overview/). Un `Yaml` o `JSON` que **define la configuración de los servicios**.

Al trabajar con una arquitectura de microservicios, es necesario tener un _chequeo de salud_ antes de
correr el comando principal de los contenedores, también, contar con la **resilencia** necesaria en la
aplicación por si es que alguno de los servicios dependientes deja de funcionar.

### Desarrollo
`docker-compose` se vuelve esencial, te facilita la interacción con
los contenedores de tu aplicación y permite replicar el proyecto con un `docker-compose up`.

Siempre habrá un `docker-compose.yml` en nuestros proyectos, y probablemente un `Dockerfile`.

Si el proyecto requiere un ambiente separado para pruebas/desarrollo y otro para producción, habrá
2 archivos de Docker, `Dockerfile` y `Dockerfile.dev`, normalmente sucede cuando las pruebas
corren en un motor de renderización y necesitas instalar paquetes adicionales a los de producción.

El archivo `.gitignore` es necesario que incluya lo siguiente:

```gitignore
docker-compose.override.yml
```

Nuestro `docker-compose.yml` para un proyecto de Ruby on Rails se vería como el siguiente:
```yaml
version: '2'

volumes:
  db_data: {}
  gems: {}

services:
  db:
    image: postgres
    volumes:
      - db_data:/var/lib/postgresql/data

  web:
    image: civica-digital/nombre-del-proyecto:development
    build:
      context: .
      dockerfile: Dockerfile.dev
    command: rails s -p 3000 -b '0.0.0.0'
    depends_on:
      - db
    volumes:
      - .:/app
      - gems:/usr/local/bundle
    environment:
      - RAILS_ENV=development
```

Si necesitamos cambiar o agregar alguna configuración al archive de _compose_,
utilizaremos el archivo `docker-compose.override.yml`, un ejemplo sería ligar
el puerto expuesto de un contenedor a la red local
del anfitrión (_host_):
```yaml
version: '2'

services:
  web:
    ports:
      - 3000:3000
    environment:
      - LANG=C.UTF-8
      - TERM=xterm-256color
  db:
    ports:
      - 5432:5432
```

De esta manera, mantenemos una configuración compartida, y otra que podemos personalizar sin tener
conflictos en `git`.

> `LANG` y `TERM` son variables de ambiente que muchas veces están implícitas en nuestro contexto.
> `LANG` es el cómo se van a interpretar los caracteres.
> `TERM=xterm-256color` nos ayuda a mostrar los colores de manera adecuada.

Ahora, para no montar cosas inecesarias en nuestros contenedores, creamos un archivo que se llame `.dockerignore`, y que contenga al menos lo siguiente:

```bash
# Git
.git
.gitignore

# Docker
Dockerfile*
docker-compose*
.dockerignore

# Logfiles and tempfiles.
log/*.log
tmp/

# Documentation
README*
doc/

# Public folders
public/system/
public/assets/
public/uploads/
```

Para que la aplicación web se pueda comunicar al contenedor que tiene la base de datos,
asegúrate de tener el arhivo `config/database.yml` de la siguiente manera:
```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: 5
  host: db
  username: postgres

development:
  <<: *default
  database: development

test:
  <<: *default
  database: test
```

Cuando se usa `docker-compose up`, crea una red para que se comuniquen los contenedores internamente.
En el caso donde quieras comunicar un servicio no especificado en el `docker-compose.yml`, tendrás
que agregarlo a la red que creo `docker-compose` con el siguiente comando:

```
docker network connect [NETWORK] [CONTAINER]
```

### Producción
(En discusión)
- [Secrets in EC2](https://aws.amazon.com/blogs/security/how-to-manage-secrets-for-amazon-ec2-container-service-based-applications-by-using-amazon-s3-and-docker/)
- [Compose en producción](https://docs.docker.com/compose/production/)
- [Jenkins + Docker](https://github.com/maxfields2000/dockerjenkins_tutorial)

### Diferencias entre Docker y una máquina virtual
Una máquina virtual normalmente emula una capa de _hardware_ encima de tu sistema operativo, y después corre otro sistema operativo encima de esa capa. Esto permite correr procesos aislados completamente de tu sistema operativo _host_.

Los contenedores, usan varias herramientas de tu sistema operativo, incluyendo _espacio de nombres_, para lograr un nivel similar de aislamiento pero sin la capa extra de complejidad, haciéndolos muy ligeros.
> Traducido de [Sobre PIDs y Namespaces](https://www.toptal.com/linux/separation-anxiety-isolating-your-system-with-linux-namespaces)

### Referencias
- [Docker + Compose + Rails](https://docs.docker.com/compose/rails/)
- [Martin Fowler, sobre microservicios](https://martinfowler.com/articles/microservices.html)
- [Arquitectura de Microservicios](https://www.safaribooksonline.com/library/view/microservice-architecture/9781491956328/)
- [Kief Morris, Infrastructure as Code](https://www.safaribooksonline.com/library/view/infrastructure-as-code/9781491924334/)
- [Small is Beautiful](https://vimeo.com/148843366)
- [Conferencia de arquitectura de software de O'Reilly](https://www.safaribooksonline.com/library/view/oreilly-software-architecture/9781491944615/)
- [Docker how-tos and best practices](https://success.docker.com/Datacenter/Apply)
- [Xterm - ArchWiki](https://wiki.archlinux.org/index.php/Xterm)
- [Sobre PIDs y Namespacing](https://www.toptal.com/linux/separation-anxiety-isolating-your-system-with-linux-namespaces)
- [(Linux) Docker y la posesión de archivos y permisos](http://stackoverflow.com/questions/26500270/understanding-user-file-ownership-in-docker-how-to-avoid-changing-permissions-o#29584184)
