# DevOps Pipeline Quick Reference 📚

## 🎯 ONE-COMMAND DEPLOYMENT

### Complete Pipeline Setup
```bash
# Windows
deploy-complete.bat

# Linux/Mac/Git Bash
./deploy-complete-pipeline.sh
```

**This single command does EVERYTHING:**
- ✅ AWS infrastructure deployment
- ✅ All DevOps tools installation
- ✅ Complete tool integration setup
- ✅ JIRA integration (optional)
- ✅ Integration testing
- ✅ Service verification

**Time:** ~15-20 minutes | **Result:** Complete working pipeline!

---

## 🎯 Manual Management Commands

### Infrastructure Deployment
```bash
# Deploy everything
terraform init && terraform apply

# Connect to instance
ssh -i "Pair06.pem" ec2-user@<instance-ip>

# Install all services
./install-elk.sh && ./install-jenkins.sh && ./install-sonarqube.sh && ./install-tomcat.sh

# Setup integrations
./install-jira-integration.sh && ./create-jenkins-jobs.sh

# Verify installation
./integration-tests.sh
```

### Service Management
```bash
# Check all services
docker ps

# Restart all services
./restart-all-services.sh

# View logs
docker logs <service-name>

# Service status
./service-status.sh
```

## 🌐 Access URLs

| Service | URL | Default Credentials |
|---------|-----|-------------------|
| Jenkins | `http://<ip>:8080` | admin / `docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword` |
| SonarQube | `http://<ip>:9000` | admin / admin |
| Kibana | `http://<ip>:10101` | - |
| Tomcat | `http://<ip>:8081` | - |
| Elasticsearch | `http://<ip>:10100` | - |

## 🔧 Common Tasks

### Jenkins Pipeline Creation
```groovy
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                sh 'npm install && npm run build'
            }
        }
        stage('Test') {
            steps {
                sh 'npm test'
            }
        }
        stage('SonarQube') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh 'npx sonar-scanner'
                }
            }
        }
        stage('Deploy') {
            steps {
                sh 'cp build/* /opt/tomcat/webapps/'
            }
        }
    }
}
```

### SonarQube Project Setup
```bash
# Create sonar-project.properties
cat > sonar-project.properties << EOF
sonar.projectKey=react-app
sonar.projectName=React Application
sonar.sources=src
sonar.exclusions=**/*.test.js,**/node_modules/**
sonar.javascript.lcov.reportPaths=coverage/lcov.info
EOF
```

### JIRA Integration
```bash
# Configure JIRA
export JIRA_URL="https://your-instance.atlassian.net"
export JIRA_USERNAME="your-email@company.com"
export JIRA_API_TOKEN="your-api-token"

# Test connection
curl -u $JIRA_USERNAME:$JIRA_API_TOKEN $JIRA_URL/rest/api/3/myself
```

## 🚨 Troubleshooting

### Service Not Starting
```bash
# Check Docker status
sudo systemctl status docker

# Check container logs
docker logs <container-name> --tail 50

# Restart specific service
docker restart <container-name>

# Check disk space
df -h

# Check memory usage
free -h
```

### Integration Issues
```bash
# Test connectivity between services
curl -I http://localhost:8080  # Jenkins
curl -I http://localhost:9000  # SonarQube
curl -I http://localhost:9200  # Elasticsearch

# Check network connectivity
docker network ls
docker network inspect <network-name>
```

### Build Failures
```bash
# Check Jenkins logs
docker exec jenkins tail -f /var/log/jenkins/jenkins.log

# Check Node.js in Jenkins
docker exec jenkins node --version
docker exec jenkins npm --version

# Manual build test
docker exec jenkins sh -c "cd /var/jenkins_home/workspace/<job-name> && npm install && npm test"
```

## 📊 Monitoring Commands

### System Health
```bash
# Container status
docker stats --no-stream

# Service health checks
curl -s http://localhost:8080/login | grep -q "Jenkins" && echo "Jenkins: UP" || echo "Jenkins: DOWN"
curl -s http://localhost:9000/api/system/status | jq -r '"SonarQube: " + .status'
curl -s http://localhost:9200/_cluster/health | jq -r '"Elasticsearch: " + .status'
```

### Performance Monitoring
```bash
# CPU and Memory usage
top -bn1 | grep -E "(Cpu|Mem)"

# Disk usage
docker system df

# Network connections
netstat -tulpn | grep -E "(8080|9000|9200|5601)"
```

## 🔐 Security Checklist

### Initial Setup
- [ ] Change default passwords
- [ ] Configure SSL certificates
- [ ] Set up user authentication
- [ ] Configure firewall rules
- [ ] Enable audit logging

### Regular Maintenance
- [ ] Update service versions
- [ ] Review access logs
- [ ] Backup configurations
- [ ] Monitor security alerts
- [ ] Review user permissions

## 📁 Important File Locations

### Configuration Files
```bash
# Jenkins
/var/jenkins_home/config.xml
/var/jenkins_home/jobs/

# SonarQube
/opt/sonarqube/conf/sonar.properties

# ELK Stack
/etc/elasticsearch/elasticsearch.yml
/etc/logstash/conf.d/
/etc/kibana/kibana.yml

# Tomcat
/usr/local/tomcat/conf/server.xml
/usr/local/tomcat/webapps/
```

### Log Files
```bash
# Application logs
/var/log/jenkins/jenkins.log
/opt/sonarqube/logs/sonarqube.log
/usr/local/tomcat/logs/catalina.out

# Docker logs
docker logs jenkins
docker logs sonarqube
docker logs elasticsearch
```

## 🔄 Backup & Recovery

### Backup Commands
```bash
# Jenkins backup
docker exec jenkins tar -czf jenkins-backup.tar.gz /var/jenkins_home

# SonarQube database backup
docker exec sonarqube-db pg_dump -U sonar sonar > sonarqube-backup.sql

# Configuration backup
cp -r /etc/docker/compose/ backup/
```

### Recovery Commands
```bash
# Restore Jenkins
docker exec jenkins tar -xzf jenkins-backup.tar.gz -C /

# Restore SonarQube database
docker exec -i sonarqube-db psql -U sonar sonar < sonarqube-backup.sql

# Restart services after restore
docker-compose restart
```

## 🚀 Deployment Strategies

### Blue-Green Deployment
```bash
# Deploy to green environment
docker run -d --name app-green -p 8082:8080 react-app:latest

# Test green environment
curl http://localhost:8082/health

# Switch traffic (update load balancer)
# Stop blue environment
docker stop app-blue
```

### Rolling Deployment
```bash
# Update instances one by one
for instance in $(docker ps --filter "name=app" --format "{{.Names}}"); do
    docker stop $instance
    docker rm $instance
    docker run -d --name $instance react-app:latest
    sleep 30  # Wait for health check
done
```

## 📈 Performance Optimization

### Jenkins Performance
```bash
# Increase Java heap size
docker exec jenkins sh -c 'echo "JAVA_OPTS=-Xmx2048m -Xms1024m" >> /etc/default/jenkins'

# Clean up old builds
docker exec jenkins find /var/jenkins_home/jobs -name "builds" -exec rm -rf {}/*/archive \;
```

### SonarQube Performance
```bash
# Increase database connections
docker exec sonarqube-db psql -U sonar -c "ALTER SYSTEM SET max_connections = 200;"

# Optimize Elasticsearch settings
docker exec sonarqube sh -c 'echo "sonar.search.javaOpts=-Xmx1024m" >> /opt/sonarqube/conf/sonar.properties'
```

## 🎨 Customization Examples

### Custom Jenkins Plugin Installation
```groovy
// plugins.txt
pipeline-stage-view:2.18
sonar:2.13
github:1.34.1
jira:3.7
```

### Custom SonarQube Quality Profile
```xml
<!-- quality-profile.xml -->
<profile>
    <name>React Custom Profile</name>
    <language>js</language>
    <rules>
        <rule>
            <repositoryKey>javascript</repositoryKey>
            <key>S1442</key>
            <severity>BLOCKER</severity>
        </rule>
    </rules>
</profile>
```

### Custom Kibana Dashboard
```json
{
  "version": "7.17.0",
  "objects": [
    {
      "type": "dashboard",
      "attributes": {
        "title": "Pipeline Metrics",
        "panels": []
      }
    }
  ]
}
```

---

## 📞 Support Resources

### Documentation Links
- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [SonarQube Documentation](https://docs.sonarqube.org/)
- [Elasticsearch Documentation](https://www.elastic.co/guide/)
- [Docker Documentation](https://docs.docker.com/)

### Useful Commands Reference
```bash
# Docker management
docker system prune -a                    # Clean everything
docker volume ls                          # List volumes
docker network ls                         # List networks
docker exec -it <container> /bin/bash     # Access container shell

# System monitoring
htop                                       # Process monitor
iotop                                      # Disk I/O monitor
nethogs                                    # Network monitor
```

### Emergency Procedures
```bash
# Service recovery
./restart-all-services.sh

# Full system reset (use with caution)
docker system prune -a --volumes
terraform destroy && terraform apply

# Backup before major changes
./backup-all-configs.sh
```

---

*Quick Reference Guide - Keep this handy for daily operations*