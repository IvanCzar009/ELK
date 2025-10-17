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
  filter {
    name   = "availability-zone"
    values = ["${var.region}a"]
  }
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

  tags = {
    Name        = var.instance_name
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "DevOps CI/CD Pipeline"
  }

  # Connection configuration for remote-exec
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("${path.module}/Pair06.pem")
    host        = self.public_ip
    timeout     = "10m"
  }

  # Wait for instance to be ready
  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for instance to be ready...'",
      "sudo cloud-init status --wait",
      "echo 'Instance is ready!'",
      "echo 'Current time: $(date)'",
      "echo 'Instance details:'",
      "echo 'Hostname: $(hostname)'",
      "echo 'Uptime: $(uptime)'",
      "echo 'Disk space: $(df -h /)'",
      "echo 'Memory: $(free -h)'"
    ]
  }

  # System update and basic setup
  provisioner "remote-exec" {
    inline = [
      "echo '=== Starting System Update ==='",
      "sudo yum update -y",
      "echo '=== Installing Required Packages ==='",
      "sudo yum install -y curl wget git unzip docker jq",
      "echo '=== Setting up Docker ==='",
      "sudo systemctl start docker",
      "sudo systemctl enable docker",
      "sudo usermod -a -G docker ec2-user",
      "echo '=== Installing Docker Compose ==='",
      "sudo curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose",
      "sudo chmod +x /usr/local/bin/docker-compose",
      "echo '=== Setting up Directories ==='",
      "sudo mkdir -p /opt/devops/{scripts,logs}",
      "sudo chown -R ec2-user:ec2-user /opt/devops/",
      "echo '=== Basic setup completed! ==='",
      "docker --version",
      "docker-compose --version"
    ]
  }

  # Copy installation scripts
  provisioner "file" {
    source      = "${path.module}/install-elk.sh"
    destination = "/opt/devops/scripts/install-elk.sh"
  }

  provisioner "file" {
    source      = "${path.module}/install-jenkins.sh"
    destination = "/opt/devops/scripts/install-jenkins.sh"
  }

  provisioner "file" {
    source      = "${path.module}/install-sonarqube.sh"
    destination = "/opt/devops/scripts/install-sonarqube.sh"
  }

  provisioner "file" {
    source      = "${path.module}/install-tomcat.sh"
    destination = "/opt/devops/scripts/install-tomcat.sh"
  }

  provisioner "file" {
    source      = "${path.module}/automated-creation-of-job.sh"
    destination = "/opt/devops/scripts/automated-creation-of-job.sh"
  }

  provisioner "file" {
    source      = "${path.module}/Github-integration-with-jenkins.sh"
    destination = "/opt/devops/scripts/Github-integration-with-jenkins.sh"
  }

  provisioner "file" {
    source      = "${path.module}/jenkins-integration-with-sonarqube.sh"
    destination = "/opt/devops/scripts/jenkins-integration-with-sonarqube.sh"
  }

  provisioner "file" {
    source      = "${path.module}/deployment-to-tomcat.sh"
    destination = "/opt/devops/scripts/deployment-to-tomcat.sh"
  }

  # Make scripts executable
  provisioner "remote-exec" {
    inline = [
      "echo '=== Making scripts executable ==='",
      "chmod +x /opt/devops/scripts/*.sh",
      "ls -la /opt/devops/scripts/"
    ]
  }

  # Install ELK Stack
  provisioner "remote-exec" {
    inline = [
      "echo '=== Starting ELK Stack Installation ==='",
      "cd /opt/devops/scripts",
      "./install-elk.sh 2>&1 | tee /opt/devops/logs/elk-install.log",
      "echo '=== ELK Stack Installation Completed ==='",
      "echo 'Waiting for ELK services to stabilize...'",
      "sleep 30"
    ]
  }

  # Install Jenkins
  provisioner "remote-exec" {
    inline = [
      "echo '=== Starting Jenkins Installation ==='",
      "cd /opt/devops/scripts",
      "./install-jenkins.sh 2>&1 | tee /opt/devops/logs/jenkins-install.log",
      "echo '=== Jenkins Installation Completed ==='",
      "echo 'Waiting for Jenkins to stabilize...'",
      "sleep 30"
    ]
  }

  # Install SonarQube
  provisioner "remote-exec" {
    inline = [
      "echo '=== Starting SonarQube Installation ==='", 
      "cd /opt/devops/scripts",
      "./install-sonarqube.sh 2>&1 | tee /opt/devops/logs/sonarqube-install.log",
      "echo '=== SonarQube Installation Completed ==='",
      "echo 'Waiting for SonarQube to stabilize...'",
      "sleep 60"
    ]
  }

  # Install Tomcat
  provisioner "remote-exec" {
    inline = [
      "echo '=== Starting Tomcat Installation ==='",
      "cd /opt/devops/scripts", 
      "./install-tomcat.sh 2>&1 | tee /opt/devops/logs/tomcat-install.log",
      "echo '=== Tomcat Installation Completed ==='",
      "echo 'Waiting for Tomcat to stabilize...'",
      "sleep 30"
    ]
  }

  # Verify all services
  provisioner "remote-exec" {
    inline = [
      "echo '=== Service Verification ==='",
      "echo 'Docker containers:'",
      "docker ps --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}'",
      "echo ''",
      "echo 'Health Checks:'",
      "echo -n 'Elasticsearch: '",
      "curl -s http://localhost:9200/_cluster/health | jq -r '.status' || echo 'Not ready'",
      "echo -n 'Jenkins: '", 
      "curl -s -I http://localhost:8080 | head -n 1 | cut -d' ' -f2 || echo 'Not ready'",
      "echo -n 'SonarQube: '",
      "curl -s http://localhost:9000/api/system/status | jq -r '.status' || echo 'Not ready'",
      "echo -n 'Tomcat: '",
      "curl -s -I http://localhost:8081 | head -n 1 | cut -d' ' -f2 || echo 'Not ready'",
      "echo -n 'Kibana: '",
      "curl -s -I http://localhost:5601 | head -n 1 | cut -d' ' -f2 || echo 'Not ready'"
    ]
  }

  # Setup Jenkins jobs
  provisioner "remote-exec" {
    inline = [
      "echo '=== Setting up Jenkins Jobs ==='",
      "cd /opt/devops/scripts",
      "echo 'Waiting additional time for Jenkins to be fully ready...'",
      "sleep 60",
      "./automated-creation-of-job.sh 2>&1 | tee /opt/devops/logs/jenkins-jobs.log",
      "echo '=== Jenkins Jobs Setup Completed ==='",
      "sleep 15"
    ]
  }

  # Setup integrations
  provisioner "remote-exec" {
    inline = [
      "echo '=== Setting up GitHub Integration ==='",
      "cd /opt/devops/scripts",
      "./Github-integration-with-jenkins.sh 2>&1 | tee /opt/devops/logs/github-integration.log",
      "echo '=== GitHub Integration Completed ==='",
      "sleep 15",
      "echo '=== Setting up SonarQube Integration ==='",
      "./jenkins-integration-with-sonarqube.sh 2>&1 | tee /opt/devops/logs/sonarqube-integration.log", 
      "echo '=== SonarQube Integration Completed ==='",
      "sleep 15",
      "echo '=== Setting up Tomcat Deployment ==='",
      "./deployment-to-tomcat.sh 2>&1 | tee /opt/devops/logs/tomcat-deployment.log",
      "echo '=== Tomcat Deployment Setup Completed ==='",
      "sleep 15"
    ]
  }

  # Final verification and summary
  provisioner "remote-exec" {
    inline = [
      "echo '=== FINAL INSTALLATION SUMMARY ==='",
      "echo 'Installation completed at: $(date)'",
      "echo 'Instance: ${var.instance_name}'",
      "echo 'Environment: ${var.environment}'", 
      "echo 'Project: ${var.project_name}'",
      "echo ''",
      "echo 'Service URLs:'",
      "PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)",
      "echo \"Jenkins: http://$PUBLIC_IP:8080\"",
      "echo \"SonarQube: http://$PUBLIC_IP:9000\"",
      "echo \"Kibana: http://$PUBLIC_IP:5601\"", 
      "echo \"Tomcat: http://$PUBLIC_IP:8081\"",
      "echo \"Elasticsearch: http://$PUBLIC_IP:9200\"",
      "echo ''",
      "echo 'Default Credentials:'",
      "echo 'Jenkins: admin / (check /opt/jenkins/initial-password.txt)'",
      "echo 'SonarQube: admin / admin'",
      "echo 'Tomcat Manager: admin / admin123'",
      "echo ''",
      "echo 'Installation logs available in: /opt/devops/logs/'",
      "echo 'Scripts available in: /opt/devops/scripts/'",
      "echo ''",
      "echo 'Final container status:'",
      "docker ps --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}'",
      "echo ''",
      "echo '🎉 DevOps CI/CD Pipeline is ready! 🎉'"
    ]
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