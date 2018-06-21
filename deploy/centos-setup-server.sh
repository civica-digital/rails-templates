#!/bin/bash

# The intention of this script is to setup a server with the default
# configuration, documenting (infrastructure as code) the tasks
# that we normaly use in our staging/production environments.
#
# It should be runned with a user with `sudo` powers, that doesn't require
# password for it, as many commands requires root access and runs in
# a non-interactive environment.

# As we are running this with Terraform, it interprets the $ { var }
# as interpolation, that's why we are using the $var syntax
username=${USERNAME}
project_name=${PROJECT_NAME}
aws_access_key=${AWS_ACCESS_KEY}
aws_secret_key=${AWS_SECRET_KEY}
app_dir="/var/www/$project_name"
admin_username="azurevm"

main() {
  add_centos_repository
  create_user
  make_app_dir
  configure_ssh
  install_docker
  configure_docker
  install_docker_compose
  configure_docker_compose
  install_python_pip
  install_awscli
  configure_awscli
}

add_centos_repository() {
  cat <<EOF > /etc/yum.repos.d/centos.repo
[Centos-Base]
name=CentOS 7 - BASE
mirrorlist=http://mirrorlist.centos.org/?release=7&arch=x86_64&repo=os
enabled=1
gpgcheck=1
gpgkey=http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-7
EOF

  sudo rpm --import http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-7

  sudo yum install -y epel-release
}

create_user() {
  # Creates a user (by default, named `deploy`) without sudo
  # copies the SSH keys from the admin user
  useradd --create-home --shell /bin/bash $username

  cp -R /home/$admin_username/.ssh /home/$username/

  # Removing possible restrictions
  sed -E -i 's/^.*(ssh-rsa)/\1/' /home/$username/.ssh/authorized_keys
  chown -R $username:$username /home/$username/.ssh
}

make_app_dir() {
  # Creates a directory with the project name, and allows
  # the user access to manage it
  mkdir -p $app_dir
  chown -R $username:$username $app_dir
}

configure_ssh() {
  # Change the sshd config to sane defaults

  cat <<'EOF' > /etc/ssh/sshd_config
AcceptEnv LANG LC_*
AuthenticationMethods publickey
ChallengeResponseAuthentication no
HostKey /etc/ssh/ssh_host_dsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key
LogLevel VERBOSE
PasswordAuthentication no
PermitRootLogin no
Port 22
PrintLastLog yes
PrintMotd yes
Protocol 2
SyslogFacility AUTHPRIV
UsePAM yes
UsePrivilegeSeparation sandbox
X11Forwarding no
EOF

  systemctl restart sshd
}

install_docker() {
  # https://docs.docker.com/engine/installation/linux/docker-ce/centos/#install-docker-ce

  sudo yum install -y yum-utils \
                      device-mapper-persistent-data \
                      lvm2

  sudo yum-config-manager \
      --add-repo \
      https://download.docker.com/linux/centos/docker-ce.repo

  sudo yum install -y docker-ce

  # Enable Docker as a daemon and start it
  sudo systemctl enable docker
  sudo systemctl start docker
}

configure_docker() {
  # Add user to the Docker group and specify some useful functions
  sudo usermod -a -G docker $username

  # Using .bash_profile, as it takes more priority than .profile
  cat <<EOF>> /home/$username/.bash_profile

export COMPOSE_FILE=$app_dir/docker-compose.yml
alias dc=docker-compose
alias web-index="dc ps | grep -Eio 'web_[0-9]+' | grep -Eo '[0-9]+'"
shell() { dc exec --index=\$(web-index) web bash ; }
rails() { dc exec --index=\$(web-index) web rails \$@ ; }
rake() { dc exec --index=\$(web-index) web rake \$@ ; }
logs() { dc logs --index=\$(web-index) --tail=500 -f web ; }
EOF
}

install_docker_compose() {
  sudo curl -L https://github.com/docker/compose/releases/download/1.21.2/docker-compose-`uname -s`-`uname -m` -o docker-compose
  sudo mv docker-compose /usr/local/bin/
  sudo chmod +x /usr/local/bin/docker-compose
}

configure_docker_compose() {
  # Create an acme.json for Traefik SSL
  touch $app_dir/acme.json
  sudo chmod 600 $app_dir/acme.json

  sudo chown -R $username:$username $app_dir
}

install_python_pip() {
  # The CentOS 7 distro doesn't ship with `pip` in Digital Ocean
  sudo yum install -y python-pip
  sudo pip install --upgrade pip
}

install_awscli() {
  # Mostly, used to login to ECR (where we host our Docker images)
  sudo pip install awscli
}

configure_awscli() {
  # Add the default profile to the user
  local aws_dir="/home/$username/.aws"

  mkdir -p $aws_dir

  cat <<EOF > $aws_dir/config
[default]
output = json
region = us-east-1
EOF

  cat <<EOF > $aws_dir/credentials
[default]
aws_access_key_id = $aws_access_key
aws_secret_access_key = $aws_secret_key
EOF

  chmod 600 $aws_dir/*
  chown -R $username:$username $aws_dir
}

main
