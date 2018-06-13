#!/usr/bin/env bash

((${#} != 1)) && echo "Usage: update-container.sh IMAGE"

image=${1}

main() {
  login_to_aws
  download_image
  test_container
  run_migrations
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

test_container() {
  local env_file="${COMPOSE_FILE%/*}/environment"

  docker run --detach --env-file ${env_file} --name testing ${image}

  pending_migrations=$(docker exec testing rails db:migrate:status \
                        | awk'{print $1}' \
                        | grep --count 'down')

  [[ ${pending_migrations} > 0 ]] && docker exec testing rails db:migrate

  sleep 3

  ip=$(docker inspect
        -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' \
        testing)

  health=$(curl --fail --silent "${ip}:3000/status")

  if [[ -z "${health}" ]]; then
    seq ${pending_migrations} | xargs -I{} docker exec testing rails db:rollback
    docker rm -f testing
    echo "Image not responding correctly, check rollbar for more details"
    exit 1
  else
    docker rm -f testing
  fi
}

recreate_services() {
  old_container=$(docker ps --filter name=web -q | head -n 1)

  docker-compose up -d --no-recreate --scale web=2

  new_container=$(docker ps --filter name=web -q | head -n 1)
  sleep 5;
  docker stop $old_container && docker rm -f $old_container
  docker-compose up -d --no-recreate --scale web=1
  docker-compose up -d
}

run_seeds() {
  docker-compose run --rm web sh -c 'wait_pg && rake db:seed'
}

run_migrations() {
  docker-compose run --rm web sh -c 'wait_pg && rake db:create db:migrate'
}

clean() {
  set +xeu
  # Remove images that are not being used by any container
  docker images -q | xargs docker rmi -f 2> /dev/null; true
  set -xeu
}

set -xeuo pipefail
main
