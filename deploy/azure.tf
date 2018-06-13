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

variable "azure_client_id" {}
variable "azure_client_secret" {}
variable "azure_tenant_id" {}
variable "azure_subscription_id" {}

variable "cloudflare_email" {}
variable "cloudflare_token" {}

# ----------------------------------------------------------------------
#  Providers
# ----------------------------------------------------------------------
provider "azurerm" {
  client_id       = "${var.azure_client_id}"
  client_secret   = "${var.azure_client_secret}"
  tenant_id       = "${var.azure_tenant_id}"
  subscription_id = "${var.azure_subscription_id}"
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
#  Resource Group (Azure)
# ----------------------------------------------------------------------
resource "azurerm_resource_group" "app" {
  name = "${var.project_name}"
  location = "eastus"

  tags {
    environment = "${var.environment}"
    source      = "terraform"
  }
}

# ----------------------------------------------------------------------
#  Network (Azure)
# ----------------------------------------------------------------------
resource "azurerm_virtual_network" "app" {
  name                = "${var.project_name}-virtual-network"
  resource_group_name = "${azurerm_resource_group.app.name}"
  location            = "${azurerm_resource_group.app.location}"
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                      = "${var.project_name}-subnet"
  resource_group_name       = "${azurerm_resource_group.app.name}"
  virtual_network_name      = "${azurerm_virtual_network.app.name}"
  address_prefix            = "10.0.2.0/24"
}

module "network-security-group" {
  source              = "Azure/network-security-group/azurerm"
  resource_group_name = "${azurerm_resource_group.app.name}"
  location            = "${azurerm_resource_group.app.location}"
  security_group_name = "web"
  predefined_rules    = [
    { name = "SSH" },
    { name = "HTTP" },
    { name = "HTTPS" }
  ]
}

resource "azurerm_public_ip" "app" {
  name                         = "${var.project_name}-public-ip"
  resource_group_name          = "${azurerm_resource_group.app.name}"
  location                     = "${azurerm_resource_group.app.location}"
  public_ip_address_allocation = "Static"
}

resource "azurerm_network_interface" "app" {
  name                      = "${var.project_name}-network-interface"
  location                  = "${azurerm_resource_group.app.location}"
  resource_group_name       = "${azurerm_resource_group.app.name}"
  network_security_group_id = "${module.network-security-group.network_security_group_id}"

  ip_configuration {
    name                          = "${var.project_name}-ipconfig"
    subnet_id                     = "${azurerm_subnet.subnet.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.app.id}"
  }
}

# ----------------------------------------------------------------------
#  Web server (Azure)
# ----------------------------------------------------------------------
resource "azurerm_virtual_machine" "web" {
  name                          = "${var.project_name}"
  location                      = "${azurerm_resource_group.app.location}"
  resource_group_name           = "${azurerm_resource_group.app.name}"
  network_interface_ids         = ["${azurerm_network_interface.app.id}"]
  delete_os_disk_on_termination = true

  # https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-general
  vm_size             = "Standard_DS1_v2" # 1 vCPU, 3.5G Memory

  storage_os_disk {
    name              = "${var.project_name}-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "7-CI"
    version   = "latest"
  }

  os_profile {
    computer_name  = "${var.project_name}"
    admin_username = "azurevm"
    custom_data = "${data.template_file.setup_server.rendered}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/azurevm/.ssh/authorized_keys"
      key_data = "${var.jenkins_ssh_public_key}"
    }
  }

  tags = {
    environment = "${var.environment}"
    source      = "terraform"
  }
}

data "template_file" "setup_server" {
  template = "${file("./scripts/setup-server.sh")}"

  vars {
    PROJECT_NAME   = "${var.project_name}"
    USERNAME       = "deploy"
    AWS_ACCESS_KEY = "${aws_iam_access_key.project.id}"
    AWS_SECRET_KEY = "${aws_iam_access_key.project.secret}"
  }
}

# ----------------------------------------------------------------------
#  File storage (S3)
# ----------------------------------------------------------------------
resource "aws_s3_bucket" "file-storage" {
  bucket = "${var.project_name}-staging"
  acl    = "private"

  tags {
    Environment = "staging"
  }

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
#  Email provider (SES)
# ----------------------------------------------------------------------
resource "aws_iam_user_policy" "ses" {
  name = "${var.project_name}-SES"
  user = "${aws_iam_user.project.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ses:*",
      "Resource": "*"
    }
  ]
}
EOF
}

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
  value = "${azurerm_public_ip.app.ip_address}"
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

output "bucket" {
  value = "${aws_s3_bucket.file-storage.bucket}"
}
