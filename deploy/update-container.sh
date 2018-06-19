#!/usr/bin/env bash

((${#} != 1)) && echo "Usage: update-container.sh IMAGE"

image=${1}

main() {
  login_to_aws
  download_image
  update_compose_file
  run_migrations
  run_seeds
  recreate_services
  clean
}

login_to_aws() {
  $(aws ecr get-login --no-include-email)
}

download_image() {
  docker pull ${image}
}

update_compose_file() {
  sed -i "s#image.*amazon.*#image: ${image}#g" ${COMPOSE_FILE}
}

recreate_services() {
  old_container=$(docker ps --filter name=web -q | head -n 1)
  docker-compose up -d --no-recreate --scale web=2
  sleep 3;
  docker stop $old_container && docker rm -f $old_container
  docker-compose up -d --no-recreate --scale web=1
  docker-compose up -d
}

run_seeds() {
  docker-compose run --rm web sh -c 'wait_pg && rake db:seed'
}

run_migrations() {
  docker-compose run --rm web sh -c 'wait_pg && rake db:migrate'
}

clean() {
  set +xeu
  # Remove images that are not being used by any container
  docker images -q | xargs docker rmi -f 2> /dev/null; true
  set -xeu
}

set -xeuo pipefail
main
