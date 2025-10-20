# EC2 Instance Variables from Credentials.env
variable "ami_id" {
  description = "AMI ID for EC2 instance"
  type        = string
  default     = "ami-0945610b37068d87a"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.2xlarge"
}

variable "key_name" {
  description = "Key pair name for EC2 access"
  type        = string
  default     = "Pair06"
}

# Instance Configuration Variables
variable "instance_name" {
  description = "Name for the EC2 instance"
  type        = string
  default     = "ELK_Terraform"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "ELK-CI-CD-Pipeline"
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 20
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the instance"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Kibana Authentication Variables
variable "kibana_username" {
  description = "Username for Kibana authentication"
  type        = string
  default     = "kibana_admin"
}

variable "kibana_password" {
  description = "Password for Kibana authentication"
  type        = string
  default     = "kibana123"
  sensitive   = true
}