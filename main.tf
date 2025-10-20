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

# Get available subnets and select the first one
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

data "aws_subnet" "default" {
  id = data.aws_subnets.default.ids[0]
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

  # Elasticsearch port (changed from 9200 to 10100)
  ingress {
    from_port   = 10100
    to_port     = 10100
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Kibana port (changed from 5601 to 10101)
  ingress {
    from_port   = 10101
    to_port     = 10101
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Logstash port (changed from 5044 to 15000)
  ingress {
    from_port   = 15000
    to_port     = 15000
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
      "sudo yum install -y curl wget git unzip jq",
      "echo '=== Installing Docker ==='",
      "sudo amazon-linux-extras install docker -y || sudo yum install -y docker",
      "echo '=== Setting up Docker ==='",
      "sudo systemctl start docker",
      "sudo systemctl enable docker",
      "sudo usermod -a -G docker ec2-user",
      "echo '=== Verifying Docker Installation ==='",
      "sudo systemctl status docker --no-pager",
      "echo '=== Installing Docker Compose ==='",
      "sudo curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose",
      "sudo chmod +x /usr/local/bin/docker-compose",
      "echo '=== Setting up Directories ==='",
      "sudo mkdir -p /opt/devops/{scripts,logs}",
      "sudo chown -R ec2-user:ec2-user /opt/devops/",
      "echo '=== Basic setup completed! ==='",
      "docker --version",
      "docker-compose --version",
      "echo '=== Docker group membership (will take effect after re-login) ==='",
      "groups ec2-user"
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
    source      = "${path.module}/create-jenkins-jobs.sh"
    destination = "/opt/devops/scripts/create-jenkins-jobs.sh"
  }

  provisioner "file" {
    source      = "${path.module}/integration-tests.sh"
    destination = "/opt/devops/scripts/integration-tests.sh"
  }

  provisioner "file" {
    source      = "${path.module}/install-jira-integration.sh"
    destination = "/opt/devops/scripts/install-jira-integration.sh"
  }

  # Make scripts executable
  provisioner "remote-exec" {
    inline = [
      "echo '=== Making scripts executable ==='",
      "chmod +x /opt/devops/scripts/install-elk.sh",
      "chmod +x /opt/devops/scripts/install-jenkins.sh",
      "chmod +x /opt/devops/scripts/install-sonarqube.sh",
      "chmod +x /opt/devops/scripts/install-tomcat.sh",
      "chmod +x /opt/devops/scripts/create-jenkins-jobs.sh",
      "chmod +x /opt/devops/scripts/integration-tests.sh",
      "chmod +x /opt/devops/scripts/install-jira-integration.sh",
      "echo '=== Verifying script permissions ==='",
      "ls -la /opt/devops/scripts/",
      "echo '=== All scripts are now executable ==='",
      "file /opt/devops/scripts/*.sh"
    ]
  }

  # Install ELK Stack
  provisioner "remote-exec" {
    inline = [
      "echo '=== Starting ELK Stack Installation ==='",
      "cd /opt/devops/scripts",
      "export KIBANA_USERNAME='${var.kibana_username}'",
      "export KIBANA_PASSWORD='${var.kibana_password}'",
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
      "curl -s http://localhost:10100/_cluster/health | jq -r '.status' || echo 'Not ready'",
      "echo -n 'Jenkins: '", 
      "curl -s -I http://localhost:8080 | head -n 1 | cut -d' ' -f2 || echo 'Not ready'",
      "echo -n 'SonarQube: '",
      "curl -s http://localhost:9000/api/system/status | jq -r '.status' || echo 'Not ready'",
      "echo -n 'Tomcat: '",
      "curl -s -I http://localhost:8081 | head -n 1 | cut -d' ' -f2 || echo 'Not ready'",
      "echo -n 'Kibana: '",
      "curl -s -I http://localhost:10101 | head -n 1 | cut -d' ' -f2 || echo 'Not ready'"
    ]
  }

  # Setup Jenkins jobs
  provisioner "remote-exec" {
    inline = [
      "echo '=== Setting up Jenkins Jobs ==='",
      "cd /opt/devops/scripts",
      "echo 'Waiting additional time for Jenkins to be fully ready...'",
      "sleep 60",
      "./create-jenkins-jobs.sh 2>&1 | tee /opt/devops/logs/jenkins-jobs.log",
      "echo '=== Jenkins Jobs Setup Completed ==='",
      "sleep 15"
    ]
  }

  # Note: Additional integrations can be set up manually after deployment
  # GitHub integration, SonarQube advanced configuration, and deployment scripts
  # can be configured through the respective web interfaces

  # Copy React App and run integration tests
  provisioner "file" {
    source      = "${path.module}/group6-react-app"
    destination = "/home/ec2-user/"
  }

  provisioner "remote-exec" {
    inline = [
      "echo '=== Setting up React App Integration ==='",
      "cd /home/ec2-user",
      "sudo chown -R ec2-user:ec2-user group6-react-app/",
      "chmod +x group6-react-app/deploy.sh 2>/dev/null || true",
      "chmod +x group6-react-app/deploy-enhanced.sh 2>/dev/null || true",
      "echo '=== React App Files Copied Successfully ==='",
      "ls -la group6-react-app/",
      "echo '=== Running Integration Tests ==='",
      "cd /opt/devops/scripts",
      "./integration-tests.sh 2>&1 | tee /opt/devops/logs/integration-tests.log",
      "echo '=== Integration Tests Completed ==='",
      "sleep 10"
    ]
  }

  # Copy and setup monitoring script
  provisioner "file" {
    source      = "${path.module}/configure-monitoring.sh"
    destination = "/opt/devops/scripts/configure-monitoring.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "echo '=== Setting up Basic Monitoring ==='",
      "cd /opt/devops/scripts",
      "chmod +x configure-monitoring.sh",
      "./configure-monitoring.sh 2>&1 | tee /opt/devops/logs/monitoring-setup.log",
      "echo '=== Basic Monitoring Setup Completed ==='",
      "sleep 10"
    ]
  }

  # Copy and setup sample pipeline script
  provisioner "file" {
    source      = "${path.module}/sample-pipeline.sh"
    destination = "/opt/devops/scripts/sample-pipeline.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "echo '=== Setting up Sample CI/CD Pipeline Workflows ==='",
      "cd /opt/devops/scripts",
      "chmod +x sample-pipeline.sh",
      "./sample-pipeline.sh 2>&1 | tee /opt/devops/logs/sample-pipeline-setup.log",
      "echo '=== Sample Pipeline Workflows Setup Completed ==='",
      "sleep 10"
    ]
  }

  # Install Jira Integration
  provisioner "remote-exec" {
    inline = [
      "echo '=== Setting up Jira Integration ==='",
      "cd /opt/devops/scripts",
      "./install-jira-integration.sh 2>&1 | tee /opt/devops/logs/jira-integration-setup.log",
      "echo '=== Jira Integration Setup Completed ==='",
      "sleep 30"
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
      "echo 'DevOps Scripts Deployed:'",
      "echo '1. integration-tests.sh - Foundation validation'",
      "echo '2. setup-elk-logging.sh - ELK logging integration'", 
      "echo '3. configure-monitoring.sh - Basic monitoring setup'",
      "echo '4. sample-pipeline.sh - Complete CI/CD workflows'",
      "echo '5. install-jira-integration.sh - Jira project management integration'",
      "echo ''",
      "echo 'Service URLs:'",
      "PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)",
      "echo \"Jenkins: http://$PUBLIC_IP:8080\"",
      "echo \"SonarQube: http://$PUBLIC_IP:9000\"",
      "echo \"Kibana: http://$PUBLIC_IP:10101\"", 
      "echo \"Tomcat: http://$PUBLIC_IP:8081\"",
      "echo \"Elasticsearch: http://$PUBLIC_IP:10100\"",
      "echo \"Jira: External instance (configured during deployment)\"",
      "echo ''",
      "echo 'Interactive Dashboards:'",
      "echo \"Pipeline Dashboard: sudo /opt/pipeline-samples/demos/pipeline-dashboard.sh\"",
      "echo \"Monitoring Dashboard: sudo /opt/monitoring/scripts/show-metrics-dashboard.sh\"",
      "echo ''",
      "echo 'Default Credentials:'",
      "echo 'Jenkins: admin / (check /opt/jenkins/initial-password.txt)'",
      "echo 'SonarQube: admin / admin'",
      "echo 'Tomcat Manager: admin / admin123'",
      "echo 'Elasticsearch: elastic / elastic123'",
      "echo 'Kibana: ${var.kibana_username} / ${var.kibana_password}'",
      "echo ''",
      "echo 'Quick Start Commands:'",
      "echo 'View Pipeline Dashboard: sudo /opt/pipeline-samples/demos/pipeline-dashboard.sh'",
      "echo 'Run Complete Pipeline: sudo /opt/pipeline-samples/workflows/pipeline-orchestrator.sh'",
      "echo 'View Monitoring: sudo /opt/monitoring/scripts/show-metrics-dashboard.sh'",
      "echo ''",
      "echo 'Installation logs available in: /opt/devops/logs/'",
      "echo 'Scripts available in: /opt/devops/scripts/'",
      "echo 'React App available at: /home/ec2-user/group6-react-app/'",
      "echo 'Pipeline samples available at: /opt/pipeline-samples/'",
      "echo 'Access guides: /tmp/complete-pipeline-access.txt'",
      "echo ''",
      "echo 'Final container status:'",
      "docker ps --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}'",
      "echo ''",
      "echo '🎉 Complete DevOps CI/CD Pipeline with 4 Scripts Ready! 🎉'"
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
  value       = "http://${aws_instance.devops_instance.public_ip}:10101"
}

output "tomcat_url" {
  description = "Tomcat URL"
  value       = "http://${aws_instance.devops_instance.public_ip}:8081"
}

output "elasticsearch_url" {
  description = "Elasticsearch URL"
  value       = "http://${aws_instance.devops_instance.public_ip}:10100"
}

output "jira_url" {
  description = "External Jira URL (user provided)"
  value       = "External Jira - URL configured during deployment"
}

# Credentials Output
output "jenkins_credentials" {
  description = "Jenkins login credentials"
  value = {
    url      = "http://${aws_instance.devops_instance.public_ip}:8080"
    username = "admin"
    password = "Check Jenkins container: docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword"
    note     = "Jenkins auto-generates a password. SSH to instance and run the command above to get it."
  }
  sensitive = false
}

output "sonarqube_credentials" {
  description = "SonarQube login credentials"
  value = {
    url      = "http://${aws_instance.devops_instance.public_ip}:9000"
    username = "admin"
    password = "admin"
    note     = "Default SonarQube credentials. Change password after first login."
  }
  sensitive = false
}

output "kibana_credentials" {
  description = "Kibana login credentials"
  value = {
    url      = "http://${aws_instance.devops_instance.public_ip}:10101"
    username = "elastic"
    password = "changeme"
    note     = "Default Elasticsearch/Kibana credentials configured in ELK stack."
  }
  sensitive = false
}

output "elasticsearch_credentials" {
  description = "Elasticsearch login credentials"
  value = {
    url      = "http://${aws_instance.devops_instance.public_ip}:10100"
    username = "elastic"
    password = "changeme"
    note     = "Default Elasticsearch credentials. Same as Kibana."
  }
  sensitive = false
}

output "jira_credentials" {
  description = "External Jira integration info"
  value = {
    type     = "External Jira Integration"
    note     = "Uses existing Jira instance with API token authentication"
    setup    = "Configuration completed during deployment"
    config   = "/opt/jira-integration/config/jira.env"
  }
  sensitive = false
}

output "deployment_summary" {
  description = "Complete deployment summary with all access information"
  value = {
    infrastructure = {
      instance_id = aws_instance.devops_instance.id
      public_ip   = aws_instance.devops_instance.public_ip
      private_ip  = aws_instance.devops_instance.private_ip
      region      = var.region
    }
    services = {
      jenkins = {
        url      = "http://${aws_instance.devops_instance.public_ip}:8080"
        username = "admin"
        password = "auto-generated (see jenkins_credentials output)"
      }
      sonarqube = {
        url      = "http://${aws_instance.devops_instance.public_ip}:9000"
        username = "admin"
        password = "admin"
      }
      kibana = {
        url      = "http://${aws_instance.devops_instance.public_ip}:10101"
        username = "elastic"
        password = "changeme"
      }
      elasticsearch = {
        url      = "http://${aws_instance.devops_instance.public_ip}:10100"
        username = "elastic"
        password = "changeme"
      }
      tomcat = {
        url  = "http://${aws_instance.devops_instance.public_ip}:8081"
        note = "No authentication required for Tomcat web interface"
      }
      jira = {
        type     = "External Integration"
        note     = "Uses existing Jira instance - configured during deployment"
        config   = "/opt/jira-integration/config/jira.env"
      }
    }
    next_steps = [
      "1. Access Jenkins and change the auto-generated password",
      "2. Access SonarQube and change default admin password",
      "3. Access Kibana and configure Elasticsearch indices",
      "4. Deploy your applications to Tomcat via Jenkins pipeline",
      "5. Monitor logs and metrics through ELK stack"
    ]
  }
  sensitive = false
}