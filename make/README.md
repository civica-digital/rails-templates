# Makefile
> Makefile to work with Ruby on Rails projects

## Usage
Type `make` for documentation about what you can do.

```
analyze              Run the static analysis suite
build                Build the staging/production Docker image
bundle               Rebuild the image and install the gems
ci                   Run the CI strategy (bundle, prepare, test, analyze, clean)
clean                Remove dangling images/containers and temporary files
db-clear             Database: Remove all the data
decrypt              Unlock the secrets using your GPG key
deploy               Run the deploy strategy (build, push, infra, provide, update)
dev                  Setup your Docker development environment (bundle, prepare, clean, up)
down                 Remove the containers running in background
fresh                Performs a fresh start (down, db-clear, dev)
help                 Show information about the available targets
infrastructure       Run Terraform for infrastructure change management
logs                 See the logs of the application container
prepare              Prepare the database (create, migrate, *seed)
provide              Provide the HOST with the provisions/
push                 Push the Docker image to the registry
restart              Restart the web application only
shell                Open a bash session inside the web container
test                 Run the test suite
update               Update the HOST containers with the given Docker IMAGE
up                   Start the containers with docker-compose in background
```

We have 3 Sections:

* Continuous Integration
* Continuous Deployment
* Development
