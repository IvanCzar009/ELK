# DevOps CI/CD Pipeline Infrastructure with Terraform

This repository contains Terraform configuration and automation scripts to deploy a complete DevOps CI/CD pipeline infrastructure on AWS EC2, including ELK Stack, Jenkins, SonarQube, and Tomcat.

## 🚀 Architecture Overview

The infrastructure includes:
- **EC2 Instance**: t3.2xlarge with 20GB storage
- **ELK Stack**: Elasticsearch, Logstash, and Kibana for logging and monitoring
- **Jenkins**: CI/CD automation server with pipeline jobs
- **SonarQube**: Code quality analysis and security scanning
- **Tomcat**: Application server for deployment
- **Docker**: Container platform for all services

## 📁 Project Structure

```
ELK/
├── main.tf                           # Main Terraform configuration
├── variables.tf                      # Variable definitions
├── install-elk.sh                   # ELK Stack installation script
├── install-jenkins.sh               # Jenkins installation script
├── install-sonarqube.sh             # SonarQube installation script
├── install-tomcat.sh                # Tomcat installation script
├── automated-install-runner.sh      # Main orchestration script
├── automated-creation-of-job.sh     # Jenkins job creation automation
├── Github-integration-with-jenkins.sh # GitHub integration setup
├── jenkins-integration-with-sonarqube.sh # SonarQube integration setup
├── deployment-to-tomcat.sh          # Tomcat deployment automation
├── deploy.bat                       # Windows deployment batch file
├── deploy.ps1                       # PowerShell deployment script
├── cleanup.bat                      # Cleanup script
└── README.md                        # This documentation
```

## 🎯 Features

### Infrastructure
- ✅ Automated EC2 instance provisioning
- ✅ Security group configuration with required ports
- ✅ EBS volume encryption
- ✅ Public IP assignment for external access

### DevOps Tools
- ✅ **Jenkins**: Latest LTS with pre-installed plugins
- ✅ **SonarQube**: Community edition with PostgreSQL database
- ✅ **ELK Stack**: Elasticsearch, Logstash, and Kibana
- ✅ **Tomcat**: Application server with management interface
- ✅ **Docker**: Container platform for all services

### CI/CD Pipeline
- ✅ Automated job creation in Jenkins
- ✅ GitHub webhook integration
- ✅ SonarQube code quality analysis
- ✅ Automated deployment to Tomcat
- ✅ Integration testing
- ✅ Deployment strategies (rolling, blue-green, immediate)

## 🔧 Prerequisites

Before deploying, ensure you have:

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured with credentials
3. **Terraform** installed (version >= 1.0)
4. **SSH Key Pair** created in AWS (named "Pair06" or update the variable)
5. **Git** for version control

### Required AWS Permissions
- EC2 full access
- VPC read access
- Security Groups management
- Key Pair access

## 🚀 One-Command Deployment

### Complete Pipeline Setup (Recommended)

**Windows Users:**
```cmd
deploy-complete.bat
```

**Linux/Mac Users:**
```bash
./deploy-complete-pipeline.sh
```

That's it! ✨ This single command will:
- ✅ Deploy AWS infrastructure
- ✅ Install all DevOps tools (Jenkins, SonarQube, ELK Stack, Tomcat)
- ✅ Configure integrations between all tools
- ✅ Set up JIRA integration (optional)
- ✅ Run integration tests
- ✅ Provide complete access information

**Estimated time:** 15-20 minutes

### What Gets Deployed

The one-command deployment includes:

#### Infrastructure (via Terraform)
- ✅ EC2 instance (t3.2xlarge) with optimized configuration
- ✅ Security groups with all required ports
- ✅ Public IP assignment for external access

#### DevOps Tools (Containerized)
- ✅ **Jenkins** (port 8080) - CI/CD automation server
- ✅ **SonarQube** (port 9000) - Code quality and security analysis
- ✅ **Elasticsearch** (port 10100) - Search and analytics engine
- ✅ **Kibana** (port 10101) - Data visualization dashboard
- ✅ **Logstash** (port 5000/15000) - Log processing pipeline
- ✅ **Tomcat** (port 8081) - Application deployment server
- ✅ **PostgreSQL** - SonarQube database

#### Complete Integration Setup
- ✅ Jenkins ↔ SonarQube pipeline integration
- ✅ Jenkins ↔ Tomcat deployment automation
- ✅ ELK Stack log aggregation from all services
- ✅ GitHub webhook configuration (manual step)
- ✅ JIRA integration for issue tracking (optional)

#### Testing & Verification
- ✅ Comprehensive integration tests
- ✅ Service health monitoring
- ✅ Performance optimization
- ✅ Security configuration

### Manual Step-by-Step (Advanced Users)

If you prefer manual control:

### 1. Clone and Configure

```bash
git clone <repository-url>
cd ELK
```

### 2. Update Variables (Optional)

Edit `variables.tf` if you need to change defaults:

```hcl
variable "instance_type" {
  default = "t3.2xlarge"  # Change if needed
}

variable "key_name" {
  default = "Pair06"      # Update with your key pair name
}

variable "region" {
  default = "us-east-1"   # Change region if needed
}
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Plan Deployment

```bash
terraform plan
```

### 5. Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted to confirm deployment.

### 6. Access Your Services

After deployment (approximately 10-15 minutes), access your services:

```bash
# Get the public IP
terraform output public_ip

# Service URLs will be:
# Jenkins: http://<public-ip>:8080
# SonarQube: http://<public-ip>:9000
# Kibana: http://<public-ip>:5601
# Tomcat: http://<public-ip>:8081
```

## 🔐 Default Credentials

| Service | Username | Password | Notes |
|---------|----------|----------|-------|
| Jenkins | admin | Check `/opt/jenkins/initial-password.txt` | Initial admin password |
| SonarQube | admin | admin | Change after first login |
| Tomcat Manager | admin | admin123 | Full access |
| Tomcat Deployer | deployer | deployer123 | Deployment only |

## 📊 Service Ports

| Service | Port | Purpose |
|---------|------|---------|
| SSH | 22 | Remote access |
| HTTP | 80 | Web traffic |
| HTTPS | 443 | Secure web traffic |
| Jenkins | 8080 | CI/CD Server |
| Tomcat | 8081 | Application Server |
| SonarQube | 9000 | Code Quality |
| Elasticsearch | 9200 | Search Engine |
| Kibana | 5601 | Data Visualization |
| Logstash | 5044 | Log Processing |

## 🔄 CI/CD Pipeline Jobs

The automation creates several Jenkins jobs:

### 1. Sample-Maven-Pipeline
Complete Maven CI/CD pipeline with:
- Source code checkout
- Maven build and test
- SonarQube analysis
- Deployment to Tomcat
- Integration testing

### 2. GitHub-Integration-Pipeline
GitHub webhook-triggered pipeline:
- Automatic builds on push/PR
- Multi-branch support
- Webhook configuration

### 3. SonarQube-Integration-Pipeline
Demonstrates SonarQube integration:
- Code quality analysis
- Security scanning
- Quality gate checks
- Coverage reporting

### 4. Tomcat-Deployment-Pipeline
Advanced deployment pipeline:
- Multiple deployment strategies
- Backup and rollback
- Health checks
- Performance testing

### 5. Docker-Pipeline
Docker-based application deployment:
- Container build and test
- Image deployment
- Container health checks

## 🛠 Management and Operations

### Jenkins Management
```bash
# Access Jenkins
http://<public-ip>:8080

# Get initial admin password
ssh -i your-key.pem ec2-user@<public-ip>
sudo cat /opt/jenkins/initial-password.txt
```

### SonarQube Management
```bash
# Access SonarQube
http://<public-ip>:9000

# Default login: admin/admin
# Change password after first login
```

### Tomcat Management
```bash
# Access Tomcat
http://<public-ip>:8081

# Manager interface
http://<public-ip>:8081/manager
# Login: admin/admin123
```

### ELK Stack Management
```bash
# Elasticsearch
http://<public-ip>:9200

# Kibana
http://<public-ip>:5601
```

## 🔄 GitHub Integration Setup

1. **Generate GitHub Token**:
   - Go to GitHub Settings → Developer settings → Personal access tokens
   - Generate token with repo permissions

2. **Add Webhook**:
   ```
   URL: http://<public-ip>:8080/generic-webhook-trigger/invoke?token=github-webhook-token
   Content Type: application/json
   Events: Push, Pull Request
   ```

3. **Configure Jenkins**:
   - Add GitHub credentials in Jenkins
   - Update pipeline with your repository URL

## 📈 Monitoring and Logging

### Application Logs
- **Jenkins**: Available through web interface and Docker logs
- **SonarQube**: Database and application logs
- **Tomcat**: Access and application logs
- **ELK**: Centralized logging for all services

### Health Monitoring
- All services include health check endpoints
- Automated monitoring through Jenkins jobs
- Container health status via Docker

## 🛠 Troubleshooting

### Common Issues

1. **Services not starting**:
   ```bash
   # Check Docker containers
   docker ps -a
   
   # Check specific service logs
   docker logs jenkins
   docker logs sonarqube
   docker logs tomcat
   ```

2. **Connection issues**:
   ```bash
   # Check security group rules
   aws ec2 describe-security-groups --group-ids <sg-id>
   
   # Verify instance status
   aws ec2 describe-instances --instance-ids <instance-id>
   ```

3. **Jenkins job failures**:
   - Check console output in Jenkins
   - Verify tool configurations
   - Check service connectivity

### Service Restart Commands
```bash
# SSH to instance
ssh -i your-key.pem ec2-user@<public-ip>

# Restart services
docker restart jenkins
docker restart sonarqube
docker restart tomcat
docker restart elasticsearch
docker restart kibana
docker restart logstash
```

## 🔄 Deployment Strategies

### Rolling Deployment
- Zero-downtime deployment
- Gradual service updates
- Automatic rollback on failure

### Blue-Green Deployment
- Side-by-side environments
- Instant switch over
- Quick rollback capability

### Immediate Deployment
- Fast deployment
- Service downtime during update
- Suitable for development environments

## 📊 Performance Optimization

### Instance Sizing
- **t3.2xlarge**: 8 vCPUs, 32GB RAM
- Suitable for development/testing
- Scale up for production workloads

### Storage Optimization
- 20GB root volume (encrypted)
- Consider additional EBS volumes for data
- Regular backup strategies

### Network Optimization
- Security groups restrict access
- Consider VPC for production
- Load balancer for high availability

## 🧹 Cleanup

To destroy all resources:

```bash
terraform destroy
```

Type `yes` to confirm destruction.

**Note**: This will permanently delete all resources and data.

## 📚 Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [SonarQube Documentation](https://docs.sonarqube.org/)
- [ELK Stack Documentation](https://www.elastic.co/guide/)
- [Apache Tomcat Documentation](https://tomcat.apache.org/tomcat-9.0-doc/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For issues and questions:
1. Check the troubleshooting section
2. Review service logs
3. Create an issue in the repository
4. Consult official documentation

---

**Created by**: DevOps Team  
**Last Updated**: October 2025  
**Version**: 1.0.0