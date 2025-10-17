# Terraform configuration file (main.tf) for provisioning an EC2 instance
# This script creates the necessary infrastructure for a development environment

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
}

# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Get default subnet
data "aws_subnet" "default" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = "${var.region}a"
  default_for_az    = true
}

# Create a security group for DevOps tools
resource "aws_security_group" "devops_sg" {
  name        = "${var.project_name}-sg"
  description = "Security group for DevOps CI/CD pipeline"
  vpc_id      = data.aws_vpc.default.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Jenkins port
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # SonarQube port
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Tomcat port
  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Elasticsearch port
  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Kibana port
  ingress {
    from_port   = 5601
    to_port     = 5601
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Logstash port
  ingress {
    from_port   = 5044
    to_port     = 5044
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Create an EC2 instance
resource "aws_instance" "devops_instance" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = data.aws_subnet.default.id
  vpc_security_group_ids = [aws_security_group.devops_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
    delete_on_termination = true
  }

  user_data = base64encode(templatefile("${path.module}/automated-install-runner.sh", {
    instance_name = var.instance_name
    environment   = var.environment
    project_name  = var.project_name
  }))

  tags = {
    Name        = var.instance_name
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "DevOps CI/CD Pipeline"
  }
}

# Output values
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.devops_instance.id
}

output "public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.devops_instance.public_ip
}

output "private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.devops_instance.private_ip
}

output "jenkins_url" {
  description = "Jenkins URL"
  value       = "http://${aws_instance.devops_instance.public_ip}:8080"
}

output "sonarqube_url" {
  description = "SonarQube URL"
  value       = "http://${aws_instance.devops_instance.public_ip}:9000"
}

output "kibana_url" {
  description = "Kibana URL"
  value       = "http://${aws_instance.devops_instance.public_ip}:5601"
}

output "tomcat_url" {
  description = "Tomcat URL"
  value       = "http://${aws_instance.devops_instance.public_ip}:8081"
}