# ----------------------------------------------------------------------
#  Rules
# ----------------------------------------------------------------------
.DEFAULT_GOAL := help

.PHONY: ci bundle prepare test analyze clean \
	deploy build push provide update \
	dev up down logs decrypt shell fresh \
	db-clear \
	help

# ----------------------------------------------------------------------
#  Variables
# ----------------------------------------------------------------------
APP_DIR       ?= /var/www/{{app_name}}
DEPLOY_ENV    ?= staging
HOST          ?= localhost
IMAGE         ?= $(REPOSITORY):$(TAG)
REPOSITORY    ?= civica-digital/$(DIRNAME)
TAG           ?= latest
WORKSPACE     ?= .

SED           := sed
OS            := $(shell uname -s)
RELEASE_HASH  := $(shell git rev-parse --short HEAD)
USER          := $(shell id -u):$(shell id -g)
DIRNAME       := $(shell basename $(shell pwd) | tr -d '[:punct:]')

# Use Terraform in automation:
# https://www.terraform.io/guides/running-terraform-in-automation.html
TF_IN_AUTOMATION := true

# Defaults to working directory
COMPOSE_PROJECT_NAME ?= $(DIRNAME)

# Use a different sed version for MacOS users
ifeq ($(OS), Darwin)
	SED := gsed
endif

# ----------------------------------------------------------------------
#  Continuous Integration
# ----------------------------------------------------------------------

#: Run the CI strategy (bundle, prepare, test, analyze, clean)
ci: bundle prepare test analyze clean

#: Rebuild the image and install the gems
bundle:
	docker-compose build
	@docker-compose down --remove-orphans 2> /dev/null; true
	docker-compose run --rm --no-deps web bundle install

#: Prepare the database (create, migrate, *seed)
prepare:
	docker-compose run --rm web sh -c 'wait_pg && rails db:create db:migrate db:test:prepare'
ifndef CI
	# *Run seeds only if it's outside the CI environment (we don't need them)
	docker-compose run --rm web rake db:seed
endif

#: Run the test suite
test:
	docker-compose run --rm -e RAILS_ENV=test web rake spec

#: Run the static analysis suite
analyze:
	@echo "Rubocop:"
	@docker-compose run --rm --no-deps web rubocop
	@echo "Rails Best Practices:"
	@docker-compose run --rm --no-deps web rails_best_practices; true
	@echo "Reek:"
	@docker-compose run --rm --no-deps web reek; true
	@echo "Brakeman:"
	@docker-compose run --rm --no-deps -e CI=true web brakeman --no-progress -q -w3 -z
	@echo "Bundle Audit:"
	@docker-compose run --rm --no-deps -e HOME=/tmp web bundle-audit check --update --ignore CVE-2017-5029

#: Remove dangling images/containers and temporary files
clean: down
	@docker container prune --force
	@docker rmi --force $(IMAGE); true
	@docker image prune --force
	@rm -rf tmp/*
	@rm -rf log/*

# ----------------------------------------------------------------------
#  Continuous Delivery
# ----------------------------------------------------------------------

#: Run the deploy strategy (build, push, infra, provide, update)
deploy: build push infrastructure provide update

#: Build the staging/production Docker image
build:
	docker build \
		--tag $(IMAGE) \
		--pull=true $(WORKSPACE) \
		--build-arg release_commit=$(RELEASE_HASH)
	# Persist the image layers to speed the CI builds with cache
	docker tag $(IMAGE) $(REPOSITORY):latest

#: Push the Docker image to the registry
push:
	@$(shell aws ecr get-login --no-include-email)
	docker push $(IMAGE)

#: Run Terraform for infrastructure change management
infrastructure:
	@echo "Terraform..."
	@cd deploy/$(DEPLOY_ENV); \
		terraform init -input=false; \
		terraform plan -input=false -detailed-exitcode; \
		status=$$?; \
		if [ $$status = 2 ]; then \
			terraform apply -input=false -auto-approve=true; \
			echo "There will be a downtime of ~5 min while the infrastructure is ready..."; \
			sleep 5m; \
		fi
	@git stash -a

#: Provide the HOST with the provisions/
provide: decrypt
	rsync -avz -e \
		"ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
		--progress \
		deploy/$(DEPLOY_ENV)/provisions/ $(HOST):$(APP_DIR)

#: Update the HOST containers with the given Docker IMAGE
update:
	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		$(HOST) bash -l -s < deploy/$(DEPLOY_ENV)/scripts/update-container.sh $(IMAGE)

# ----------------------------------------------------------------------
#  Development
# ----------------------------------------------------------------------

#: Setup your Docker development environment (bundle, prepare, clean, up)
dev: docker-compose.override.yml bundle prepare clean up

#: Start the containers with docker-compose in background
up:
	@docker-compose up -d

#: Remove the containers running in background
down:
	@docker-compose down --remove-orphans 2> /dev/null; true

#: Restart the web application only
restart:
	@docker-compose restart web

#: See the logs of the application container
logs:
	@docker-compose logs -f --tail 50 web

#: Unlock the secrets using your GPG key
decrypt:
	@git-crypt unlock

#: Open a bash session inside the web container
shell:
	@docker-compose exec web bash 2> /dev/null \
		|| docker-compose run --rm web bash 2> /dev/null; true

#: Database: Remove all the data
db-clear:
	@docker volume rm $(COMPOSE_PROJECT_NAME)_db

#: Performs a fresh start (down, db-clear, dev)
fresh: down db-clear dev

docker-compose.override.yml:
	@echo "version: '3'"      >> docker-compose.override.yml
	@echo "services:"         >> docker-compose.override.yml
	@echo "  web:"            >> docker-compose.override.yml
	@echo "    ports:"        >> docker-compose.override.yml
	@echo "      - 3000:3000" >> docker-compose.override.yml
ifeq ($(OS), Linux)
	@echo "    user: $(USER)" >> docker-compose.override.yml
endif

#: Show information about the available targets
help:
	@$(SED) -En '/^#:.*/{ N; s/^#: (.*)\n([A-Za-z0-9_-]+).*/\2 \1/p }' $(MAKEFILE_LIST) \
		| sort \
		| while read label desc; do printf "\033[36m%-20s\033[0m %s\n" "$$label" "$$desc"; done
