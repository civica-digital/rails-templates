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
  default = "{{app_name}}-staging"
}

# ----------------------------------------------------------------------
#  Providers
# ----------------------------------------------------------------------
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
#  Role (IAM)
# ----------------------------------------------------------------------
resource "aws_iam_role" "web" {
  name        = "${var.project_name}"
  description = "Allow ${var.project_name} to call AWS resources"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "web" {
  name = "${var.project_name}"
  role = "${aws_iam_role.web.name}"
}

# ----------------------------------------------------------------------
#  Docker repository (ECR)
# ----------------------------------------------------------------------
resource "aws_ecr_repository" "repo" {
  name = "${var.project_name}"
}

resource "aws_iam_role_policy" "ecr" {
  name = "${var.project_name}-ECR"
  role = "${aws_iam_role.web.id}"

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
#  Web server (EC2)
# ----------------------------------------------------------------------
resource "aws_instance" "web" {
  ami           = "ami-6057e21a"        # Amazon Linux AMI 2017.09.1 (HVM)
  instance_type = "t2.medium"           # 2 CPUs, 4Gb RAM
  key_name      = "civica-ci"           # Previously created and uploaded

  tags {
    Name = "${var.project_name}"
  }

  disable_api_termination = false

  user_data       = "${data.template_file.setup_server.rendered}"

  security_groups = ["${aws_security_group.web.name}"]

  iam_instance_profile = "${aws_iam_instance_profile.web.name}"
}

resource "aws_security_group" "web" {
  name        = "${var.project_name}"
  description = "Allow SSH, HTTP, and HTTPS inbound traffic"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Script to setup the server
data "template_file" "setup_server" {
  template = "${file("./scripts/setup-server.sh")}"

  vars {
    PROJECT_NAME   = "${var.project_name}"
    USERNAME       = "deploy"
    ADMIN_USERNAME = "ec2-user"
  }
}

# ----------------------------------------------------------------------
#  Elastic IP (AWS)
# ----------------------------------------------------------------------
resource "aws_eip" "web" {
  vpc      = true
  instance = "${aws_instance.web.id}"

  tags = {
    Name = "${var.project_name}"
  }
}

# ----------------------------------------------------------------------
#  Database server (RDS)
# ----------------------------------------------------------------------
resource "aws_db_instance" "database" {
  allocated_storage         = 20
  apply_immediately         = true
  engine                    = "postgres"
  engine_version            = "10.0.3"
  instance_class            = "db.t2.micro"
  identifier                = "${var.project_name}"
  final_snapshot_identifier = "${var.project_name}-final-snapshot"
  name                      = "api"
  username                  = "root"
  password                  = "${random_string.database-password.result}"
  vpc_security_group_ids    = ["${aws_security_group.database.id}"]
  backup_retention_period   = 7 # days
}

resource "random_string" "database-password" {
  length = 16
  special = false
}

resource "aws_security_group" "database" {
  name        = "${var.project_name}-db"
  description = "Allow ${var.project_name} web server"

  ingress {
    description = "Web server"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${aws_instance.web.private_ip}/32"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

# ----------------------------------------------------------------------
#  File Storage (S3)
# ----------------------------------------------------------------------
resource "aws_s3_bucket" "file-storage" {
  bucket = "${var.project_name}-file-storage"
  acl = "private"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_user_policy" "s3" {
  name = "${var.project_name}-S3"
  user = "${aws_iam_user.project.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": [
        "${aws_s3_bucket.file-storage.arn}",
        "${aws_s3_bucket.file-storage.arn}/*"
      ]
    }
  ]
}
EOF
}

# ----------------------------------------------------------------------
#  Logs (CloudWatch)
# ----------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "web" {
  name = "${var.project_name}"
}

resource "aws_iam_role_policy" "cloudwatch" {
  name = "${var.project_name}-CloudWatch"
  role = "${aws_iam_role.web.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

# ----------------------------------------------------------------------
#  DNS (Route 53)
# ----------------------------------------------------------------------
data "aws_route53_zone" "project" {
  name = # "changeme."
}

resource "aws_route53_record" "web" {
  zone_id = "${data.aws_route53_zone.project.zone_id}"
  name    = "${var.project_name}.${data.aws_route53_zone.project.name}"
  type    = "A"
  ttl     = "300"
  records = ["${aws_eip.web.public_ip}"]
}

# Output
output "ip" {
  value = "${aws_eip.web.public_ip}"
}

output "url" {
  value = "${aws_route53_record.web.name}"
}

output "aws_key_id" {
  value = "${aws_iam_access_key.project.id}"
}

output "aws_key_secret" {
  value = "${aws_iam_access_key.project.secret}"
}

output "bucket" {
  value = "${aws_s3_bucket.file-storage.bucket}"
}

output "database" {
  value = "${aws_db_instance.database.engine}://${aws_db_instance.database.username}:${random_string.database-password.result}@${aws_db_instance.database.address}/${aws_db_instance.database.name}"
}

output "docker_repository" {
  value = "${aws_ecr_repository.repo.repository_url}"
}
