# DevOps CI/CD Pipeline - Service Credentials

This file contains all the default credentials for the services in your DevOps pipeline. Please change these default passwords after initial setup for security purposes.

## 🔐 Service Access Information

### Jenkins CI/CD Server
- **URL**: `http://YOUR_PUBLIC_IP:8080`
- **Username**: `admin`
- **Password**: Check `/opt/jenkins/initial-password.txt` on the server OR use `admin`
- **Initial Setup**: 
  - First login will require the initial admin password from the file
  - You can retrieve it by SSH: `cat /opt/jenkins/initial-password.txt`
- **API Token**: Generated during setup for automation

### SonarQube Code Quality
- **URL**: `http://YOUR_PUBLIC_IP:9000`
- **Username**: `admin`
- **Password**: `admin`
- **Database**: PostgreSQL (internal)
- **Database User**: `sonarqube`
- **Database Password**: `sonarqube123`
- **Note**: You'll be prompted to change the admin password on first login

### Kibana (ELK Stack)
- **URL**: `http://YOUR_PUBLIC_IP:10101`
- **Authentication**: **ENABLED** with login required
- **Username**: `kibana_admin` (configurable via variables.tf)
- **Password**: `kibana123` (configurable via variables.tf)
- **Elasticsearch URL**: `http://YOUR_PUBLIC_IP:10100`
- **Default Index**: `logstash-*`

### Apache Tomcat Application Server
- **URL**: `http://YOUR_PUBLIC_IP:8081`
- **Manager App**: `http://YOUR_PUBLIC_IP:8081/manager`
- **Host Manager**: `http://YOUR_PUBLIC_IP:8081/host-manager`

#### Tomcat Users:
- **Admin User**:
  - Username: `admin`
  - Password: `admin123`
  - Roles: `manager-gui,admin-gui,manager-script,manager-jmx,manager-status`

- **Deployer User**:
  - Username: `deployer`
  - Password: `deployer123`
  - Roles: `manager-script`

- **Script User**:
  - Username: `script`
  - Password: `script123`
  - Roles: `manager-script,manager-jmx,manager-status`

### Elasticsearch
- **URL**: `http://YOUR_PUBLIC_IP:10100`
- **Authentication**: **ENABLED** with login required
- **Username**: `elastic`
- **Password**: `elastic123`
- **Cluster Health**: `http://YOUR_PUBLIC_IP:10100/_cluster/health`

### Logstash
- **Input Port**: `15000` (Beats input)
- **HTTP Port**: `9600` (API endpoint)
- **Configuration**: Located in `/opt/elk/logstash/config/`

## 🔗 Service Integration Credentials

### GitHub Integration
- **Webhook URL**: `http://YOUR_PUBLIC_IP:8080/github-webhook/`
- **Secret Token**: `jenkins-github-webhook-secret`
- **Jenkins GitHub Plugin**: Uses personal access tokens (configure manually)

### SonarQube Integration with Jenkins
- **SonarQube Server URL**: `http://localhost:9000`
- **SonarQube Token**: Generated automatically during setup
- **Project Key**: `my-java-project`
- **Quality Gate**: Default SonarQube quality gate

### Jenkins-Tomcat Deployment
- **Tomcat Server**: `http://localhost:8081/manager`
- **Deploy User**: `deployer`
- **Deploy Password**: `deployer123`
- **Context Path**: `/app`

## 📁 Important File Locations

### Jenkins
- **Home Directory**: `/opt/jenkins/data`
- **Initial Password**: `/opt/jenkins/initial-password.txt`
- **Plugins Directory**: `/opt/jenkins/data/plugins`
- **Jobs Directory**: `/opt/jenkins/data/jobs`

### SonarQube
- **Data Directory**: `/opt/sonarqube/data`
- **Logs Directory**: `/opt/sonarqube/logs`
- **Extensions Directory**: `/opt/sonarqube/extensions`

### ELK Stack
- **Elasticsearch Data**: `/opt/elk/elasticsearch/data`
- **Logstash Config**: `/opt/elk/logstash/config`
- **Kibana Config**: `/opt/elk/kibana/config`

### Tomcat
- **Webapps Directory**: `/opt/tomcat/webapps`
- **Logs Directory**: `/opt/tomcat/logs`
- **Configuration**: `/opt/tomcat/conf`

## 🛠️ Administrative Commands

### Docker Management
```bash
# View all running containers
docker ps

# View container logs
docker logs <container_name>

# Restart a service
docker restart <container_name>

# Stop all services
docker stop $(docker ps -q)

# Start all services
docker start $(docker ps -aq)
```

### Service Health Checks
```bash
# Jenkins health
curl -I http://localhost:8080

# SonarQube health
curl http://localhost:9000/api/system/status

# Elasticsearch health
curl http://localhost:10100/_cluster/health

# Kibana health
curl -I http://localhost:10101

# Tomcat health
curl -I http://localhost:8081
```

## 🔒 Security Recommendations

### Immediate Actions After Deployment:
1. **Change all default passwords**
2. **Configure proper authentication for Kibana and Elasticsearch**
3. **Set up SSL/TLS certificates for production use**
4. **Configure firewall rules to restrict access**
5. **Enable Jenkins security and configure proper user roles**
6. **Set up SonarQube user management**

### GitHub Integration Security:
1. **Use personal access tokens instead of passwords**
2. **Configure webhook secrets**
3. **Limit repository access permissions**

### Database Security:
1. **Change SonarQube database passwords**
2. **Configure database backups**
3. **Enable database encryption if needed**

## 📞 Troubleshooting

### Common Issues:
- **Services not starting**: Check Docker logs
- **Port conflicts**: Ensure no other services are using the same ports
- **Permission issues**: Check file ownership in data directories
- **Network connectivity**: Verify security group settings in AWS

### Log Locations:
- **Installation Logs**: `/opt/devops/logs/`
- **Service Logs**: Use `docker logs <container_name>`
- **System Logs**: `/var/log/messages`

## 📝 Notes

- This is a **development/testing setup** with default credentials
- For **production use**, implement proper security measures
- All services are configured to restart automatically
- Data is persisted in Docker volumes for container restarts
- Regular backups of important data directories are recommended

---

**⚠️ SECURITY WARNING**: These are default credentials for development purposes. Always change them in production environments and implement proper authentication and authorization mechanisms.