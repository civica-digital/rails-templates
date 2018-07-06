# ----------------------------------------------------------------------
#  Configuration
# ----------------------------------------------------------------------
terraform {
  backend "s3" {
    bucket  = "civica-terraform-backend"
    key     = "staging/{{app_name}}"
    profile = "terraform"
    region  = "us-east-1"
  }
}

# ----------------------------------------------------------------------
#  Variables
# ----------------------------------------------------------------------
variable "project_name" {
  default = "{{app_name}}"
}

variable "environment" {
  default = "staging"
}

variable "jenkins_ssh_public_key" {
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDJFJgnK26u/46BR2H7RzqtBgQ3tsPo8l3+n1TkHPLdn5TO9WXtSF+cuZGuin0u+/KGlF12EB7oWZl7Y/IlShk9vVt3r3RHFTDkvb5IoAadsrU8uMNCUqt90lV/8OkcDzZKsukL2Lwwu2B34zyb4QYfxP7gLP9BdpJWjNY6FKPgp3hc21kigRiiDflKd2T4yCx1D60BxdYRVUT6TUTAbOAk3hvvrlE4/apglIL4TZbPc2UJ39aGcE9roz/ys+KwFPQMTuUpDZGtopEtO8RFO7OjlADtJ6Nd3OJK1S4o3pWhEtR/EfxTkJEnxioq7FHw1dxt3sJUESy31SLWt83JWEO8rQWs0Oa323WBn3Mal3xiWzS7J6UtxYz4dZ/V2hVvr9gpT6bMYiw3Jfz7YPAYYS4YraRUwH75dN8vE7MIWsVuoCWNLGF3JRTrodBaRNJcKVMlUxvWCOkm9JxDkWy28c5mdtlosUBHhjPoXSQh0l39UA/ZKAiTQOhH8m5i4CC2DTM545tNlSo9eYYFy+zZ4Z6fNIrE1qgYMbFiobEXkx176GXBqmIvKRVy2Tsb9K7/k+x6dbw5ZK3/F0aX1c7VW21eWc0gH6cIkQCGCbOLPkdkqrGLSE5QcF9suMxIEFoYIGzEqQHagm5otYPeU3hXlGCl8vWweGXoMITwTq3wFSFiIw== civica-ci"
}

variable "digital_ocean_token" {}

variable "cloudflare_email" {}
variable "cloudflare_token" {}

# ----------------------------------------------------------------------
#  Providers
# ----------------------------------------------------------------------
provider "digitalocean" {
  token = "${var.digital_ocean_token}"
}

provider "cloudflare" {
  email = "${var.cloudflare_email}"
  token = "${var.cloudflare_token}"
}

# Note: The terraform profile in `~/.aws/config` is expected.
#       Credentials are in 1Password.
provider "aws" {
  profile = "terraform"
  region  = "us-east-1"
}

# ----------------------------------------------------------------------
#  Access keys
# ----------------------------------------------------------------------
resource "aws_iam_user" "project" {
  name = "${var.project_name}"
}
resource "aws_iam_access_key" "project" {
  user = "${aws_iam_user.project.name}"
}

# ----------------------------------------------------------------------
#  Docker repository (ECR)
# ----------------------------------------------------------------------
resource "aws_ecr_repository" "repo" {
  name = "${var.project_name}"
}

resource "aws_iam_user_policy" "ecr" {
  name = "${var.project_name}-ECR"
  user = "${aws_iam_user.project.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:*",
        "cloudtrail:LookupEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

# ----------------------------------------------------------------------
#  SSH key (Digital Ocean)
# ----------------------------------------------------------------------
resource "digitalocean_ssh_key" "deploy" {
  name = "civica-digital"
  public_key = "${var.jenkins_ssh_public_key}"
}

# ----------------------------------------------------------------------
#  Web server (Digital Ocean)
# ----------------------------------------------------------------------
resource "digitalocean_droplet" "web" {
  image              = "centos-7-x64"
  name               = "${var.project_name}"
  region             = "nyc3"
  size               = "s-1vcpu-1gb"
  ssh_keys           = ["${digitalocean_ssh_key.deploy.fingerprint}"]
  ipv6               = true
  private_networking = true
  user_data          = "${data.template_file.setup_server.rendered}"
}

resource "digitalocean_floating_ip" "web" {
  droplet_id = "${digitalocean_droplet.web.id}"
  region     = "${digitalocean_droplet.web.region}"
}

data "template_file" "setup_server" {
  template = "${file("./scripts/setup-server.sh")}"

  vars {
    PROJECT_NAME   = "${var.project_name}"
    USERNAME       = "deploy"
    AWS_ACCESS_KEY = "${aws_iam_access_key.project.id}"
    AWS_SECRET_KEY = "${aws_iam_access_key.project.secret}"
    ADMIN_USERNAME = "root"
  }
}
#s3--
#s3--# ----------------------------------------------------------------------
#s3--#  File storage (S3)
#s3--# ----------------------------------------------------------------------
#s3--resource "aws_s3_bucket" "file-storage" {
#s3--  bucket = "${var.project_name}-file-storage"
#s3--  acl    = "private"
#s3--
#s3--  tags {
#s3--    Environment = "staging"
#s3--  }
#s3--
#s3--  lifecycle {
#s3--    prevent_destroy = true
#s3--  }
#s3--}
#s3--
#s3--resource "aws_iam_user_policy" "s3" {
#s3--  name = "${var.project_name}-S3"
#s3--  user = "${aws_iam_user.project.name}"
#s3--
#s3--  policy = <<EOF
#s3--{
#s3--  "Version": "2012-10-17",
#s3--  "Statement": [
#s3--    {
#s3--      "Effect": "Allow",
#s3--      "Action": "s3:*",
#s3--      "Resource": [
#s3--        "${aws_s3_bucket.file-storage.arn}",
#s3--        "${aws_s3_bucket.file-storage.arn}/*"
#s3--      ]
#s3--    }
#s3--  ]
#s3--}
#s3--EOF
#s3--}
#ses--
#ses--# ----------------------------------------------------------------------
#ses--#  Email provider (SES)
#ses--# ----------------------------------------------------------------------
#ses--resource "aws_iam_user_policy" "ses" {
#ses--  name = "${var.project_name}-SES"
#ses--  user = "${aws_iam_user.project.name}"
#ses--
#ses--  policy = <<EOF
#ses--{
#ses--  "Version": "2012-10-17",
#ses--  "Statement": [
#ses--    {
#ses--      "Effect": "Allow",
#ses--      "Action": "ses:*",
#ses--      "Resource": "*"
#ses--    }
#ses--  ]
#ses--}
#ses--EOF
#ses--}

# ----------------------------------------------------------------------
#  DNS (Cloudflare)
# ----------------------------------------------------------------------
resource "cloudflare_record" "web" {
  domain  = "civicadesarrolla.me"
  name    = "${var.project_name}"
  value   = "${azurerm_public_ip.app.ip_address}"
  type    = "A"
  proxied = false
}

# Output
output "ip" {
  value = "${digitalocean_floating_ip.web.ip_address}"
}

output "url" {
  value = "${cloudflare_record.web.hostname}"
}

output "aws_key_id" {
  value = "${aws_iam_access_key.project.id}"
}

output "aws_key_secret" {
  value = "${aws_iam_access_key.project.secret}"
}
#s3--
#s3--output "bucket" {
#s3--  value = "${aws_s3_bucket.file-storage.bucket}"
#s3--}
