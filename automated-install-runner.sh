#!/bin/bash
# automated-install-runner.sh - Main installation script that orchestrates all installations

echo "=== DevOps CI/CD Pipeline Automated Installation ==="
echo "Starting installation at: $(date)"

# Template variables from Terraform
INSTANCE_NAME="${instance_name}"
ENVIRONMENT="${environment}"
PROJECT_NAME="${project_name}"

# Log all output
exec > >(tee -a /var/log/devops-install.log)
exec 2>&1

echo "Instance: $INSTANCE_NAME"
echo "Environment: $ENVIRONMENT"
echo "Project: $PROJECT_NAME"

# Update system
echo "=== Updating System ==="
sudo yum update -y

# Install required packages
echo "=== Installing Required Packages ==="
sudo yum install -y curl wget git unzip docker jq

# Start and enable Docker
echo "=== Setting up Docker ==="
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# Install Docker Compose
echo "=== Installing Docker Compose ==="
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Set up directories
echo "=== Setting up Directories ==="
sudo mkdir -p /opt/devops/scripts
sudo mkdir -p /opt/devops/logs
sudo chown -R ec2-user:ec2-user /opt/devops/

# Download installation scripts (in production, these would be downloaded from S3 or repository)
echo "=== Downloading Installation Scripts ==="
cd /opt/devops/scripts

# Create installation scripts inline (in production, download from repository)
cat > install-docker.sh <<'EOF'
#!/bin/bash
echo "=== Docker Setup ==="
sudo systemctl status docker
docker --version
docker-compose --version
echo "Docker installation complete"
EOF

cat > install-elk.sh <<'EOF'
#!/bin/bash
# install-elk.sh - Script to install Elasticsearch, Logstash, and Kibana using Docker

echo "=== Starting ELK Stack Installation ==="

# Create ELK network
echo "Creating ELK Docker network..."
docker network create elk-network 2>/dev/null || true

# Create directories for ELK data persistence
echo "Creating ELK data directories..."
sudo mkdir -p /opt/elk/elasticsearch/data
sudo mkdir -p /opt/elk/logstash/config
sudo mkdir -p /opt/elk/kibana/config
sudo chown -R 1000:1000 /opt/elk/

# Install Elasticsearch
echo "Installing Elasticsearch..."
docker run -d \
  --name elasticsearch \
  --network elk-network \
  -p 9200:9200 \
  -p 9300:9300 \
  -e "discovery.type=single-node" \
  -e "ES_JAVA_OPTS=-Xms512m -Xmx512m" \
  -e "xpack.security.enabled=false" \
  -v /opt/elk/elasticsearch/data:/usr/share/elasticsearch/data \
  docker.elastic.co/elasticsearch/elasticsearch:8.10.4

# Wait for Elasticsearch to be ready
echo "Waiting for Elasticsearch to be ready..."
sleep 60
RETRY_COUNT=0
while [ $RETRY_COUNT -lt 30 ]; do
  if curl -s http://localhost:9200/_cluster/health | grep -q '"status":"green\|yellow"'; then
    echo "Elasticsearch is ready!"
    break
  fi
  echo "Waiting for Elasticsearch... (attempt $((RETRY_COUNT + 1))/30)"
  sleep 10
  RETRY_COUNT=$((RETRY_COUNT + 1))
done

# Install Kibana
echo "Installing Kibana..."
docker run -d \
  --name kibana \
  --network elk-network \
  -p 5601:5601 \
  -e "ELASTICSEARCH_HOSTS=http://elasticsearch:9200" \
  -e "xpack.security.enabled=false" \
  docker.elastic.co/kibana/kibana:8.10.4

# Create Logstash configuration
echo "Creating Logstash configuration..."
cat > /opt/elk/logstash/logstash.conf <<'LOGSTASH_EOF'
input {
  beats {
    port => 5044
  }
  tcp {
    port => 5000
    codec => json
  }
}

filter {
  if [fields][logtype] == "jenkins" {
    grok {
      match => { "message" => "%{TIMESTAMP_ISO8601:timestamp} %{LOGLEVEL:level} %{GREEDYDATA:message}" }
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "logstash-%{+YYYY.MM.dd}"
  }
  stdout { codec => rubydebug }
}
LOGSTASH_EOF

# Install Logstash
echo "Installing Logstash..."
docker run -d \
  --name logstash \
  --network elk-network \
  -p 5044:5044 \
  -p 5000:5000 \
  -v /opt/elk/logstash/logstash.conf:/usr/share/logstash/pipeline/logstash.conf \
  docker.elastic.co/logstash/logstash:8.10.4

echo "=== ELK Stack Installation Complete ==="
EOF

cat > install-jenkins.sh <<'EOF'
#!/bin/bash
# install-jenkins.sh - Script to install Jenkins using Docker

echo "=== Starting Jenkins Installation ==="

# Create Jenkins data directory
echo "Creating Jenkins data directory..."
sudo mkdir -p /opt/jenkins/data
sudo chown -R 1000:1000 /opt/jenkins/

# Create Jenkins network
echo "Creating Jenkins Docker network..."
docker network create jenkins-network 2>/dev/null || true

# Install Jenkins
echo "Installing Jenkins..."
docker run -d \
  --name jenkins \
  --network jenkins-network \
  -p 8080:8080 \
  -p 50000:50000 \
  -v /opt/jenkins/data:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(which docker):/usr/bin/docker \
  --group-add $(getent group docker | cut -d: -f3) \
  jenkins/jenkins:lts-jdk11

# Wait for Jenkins to start
echo "Waiting for Jenkins to start..."
sleep 60

# Wait for Jenkins to be fully ready
echo "Waiting for Jenkins to be fully ready..."
RETRY_COUNT=0
while [ $RETRY_COUNT -lt 30 ]; do
  if curl -s http://localhost:8080/login > /dev/null; then
    echo "Jenkins is ready!"
    break
  fi
  echo "Jenkins is starting up... (attempt $((RETRY_COUNT + 1))/30)"
  sleep 10
  RETRY_COUNT=$((RETRY_COUNT + 1))
done

# Get initial admin password
JENKINS_PASSWORD=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "Password not found")
echo "Jenkins Initial Admin Password: $JENKINS_PASSWORD"
echo "$JENKINS_PASSWORD" > /opt/jenkins/initial-password.txt

echo "=== Jenkins Installation Complete ==="
EOF

cat > install-sonarqube.sh <<'EOF'
#!/bin/bash
# install-sonarqube.sh - Script to install SonarQube using Docker

echo "=== Starting SonarQube Installation ==="

# Create SonarQube data directories
echo "Creating SonarQube data directories..."
sudo mkdir -p /opt/sonarqube/data
sudo mkdir -p /opt/sonarqube/logs
sudo mkdir -p /opt/sonarqube/extensions
sudo mkdir -p /opt/sonarqube/postgresql
sudo chown -R 999:999 /opt/sonarqube/

# Create SonarQube network
echo "Creating SonarQube Docker network..."
docker network create sonarqube-network 2>/dev/null || true

# Install PostgreSQL for SonarQube
echo "Installing PostgreSQL database for SonarQube..."
docker run -d \
  --name sonarqube-db \
  --network sonarqube-network \
  -e POSTGRES_USER=sonarqube \
  -e POSTGRES_PASSWORD=sonarqube \
  -e POSTGRES_DB=sonarqube \
  -v /opt/sonarqube/postgresql:/var/lib/postgresql/data \
  postgres:13

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
sleep 30

# Install SonarQube
echo "Installing SonarQube..."
docker run -d \
  --name sonarqube \
  --network sonarqube-network \
  -p 9000:9000 \
  -e SONAR_JDBC_URL=jdbc:postgresql://sonarqube-db:5432/sonarqube \
  -e SONAR_JDBC_USERNAME=sonarqube \
  -e SONAR_JDBC_PASSWORD=sonarqube \
  -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
  -v /opt/sonarqube/data:/opt/sonarqube/data \
  -v /opt/sonarqube/logs:/opt/sonarqube/logs \
  -v /opt/sonarqube/extensions:/opt/sonarqube/extensions \
  sonarqube:community

echo "=== SonarQube Installation Complete ==="
EOF

cat > install-tomcat.sh <<'EOF'
#!/bin/bash
# install-tomcat.sh - Script to install Apache Tomcat using Docker

echo "=== Starting Tomcat Installation ==="

# Create Tomcat data directories
echo "Creating Tomcat data directories..."
sudo mkdir -p /opt/tomcat/webapps
sudo mkdir -p /opt/tomcat/logs
sudo mkdir -p /opt/tomcat/conf
sudo chown -R 1000:1000 /opt/tomcat/

# Create Tomcat network
echo "Creating Tomcat Docker network..."
docker network create tomcat-network 2>/dev/null || true

# Create custom server.xml for Tomcat configuration
echo "Creating Tomcat server configuration..."
cat > /opt/tomcat/conf/server.xml <<'TOMCAT_XML'
<?xml version="1.0" encoding="UTF-8"?>
<Server port="8005" shutdown="SHUTDOWN">
  <Service name="Catalina">
    <Connector port="8081" protocol="HTTP/1.1"
               connectionTimeout="20000"
               redirectPort="8443" />
    <Engine name="Catalina" defaultHost="localhost">
      <Host name="localhost"  appBase="webapps"
            unpackWARs="true" autoDeploy="true">
      </Host>
    </Engine>
  </Service>
</Server>
TOMCAT_XML

# Create tomcat-users.xml for management interface
cat > /opt/tomcat/conf/tomcat-users.xml <<'TOMCAT_USERS'
<?xml version="1.0" encoding="UTF-8"?>
<tomcat-users>
  <role rolename="manager-gui"/>
  <role rolename="manager-script"/>
  <user username="admin" password="admin123" roles="manager-gui,manager-script"/>
  <user username="deployer" password="deployer123" roles="manager-script"/>
</tomcat-users>
TOMCAT_USERS

# Install Tomcat
echo "Installing Tomcat..."
docker run -d \
  --name tomcat \
  --network tomcat-network \
  -p 8081:8081 \
  -v /opt/tomcat/webapps:/usr/local/tomcat/webapps \
  -v /opt/tomcat/logs:/usr/local/tomcat/logs \
  -v /opt/tomcat/conf/server.xml:/usr/local/tomcat/conf/server.xml \
  -v /opt/tomcat/conf/tomcat-users.xml:/usr/local/tomcat/conf/tomcat-users.xml \
  tomcat:9.0-jdk11

echo "=== Tomcat Installation Complete ==="
EOF

# Make scripts executable
chmod +x *.sh

# Install components sequentially
echo "=== Starting Component Installations ==="

# 1. Install Docker (already done)
echo "Step 1: Docker Setup"
./install-docker.sh
sleep 10

# 2. Install ELK Stack
echo "Step 2: Installing ELK Stack"
./install-elk.sh
sleep 30

# 3. Install Jenkins
echo "Step 3: Installing Jenkins"
./install-jenkins.sh
sleep 30

# 4. Install SonarQube
echo "Step 4: Installing SonarQube"
./install-sonarqube.sh
sleep 60

# 5. Install Tomcat
echo "Step 5: Installing Tomcat"
./install-tomcat.sh
sleep 30

# Verify all services are running
echo "=== Verification ==="
echo "Checking Docker containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Health checks
echo "=== Health Checks ==="

echo "Elasticsearch health:"
curl -s http://localhost:9200/_cluster/health || echo "Elasticsearch not ready"

echo "Kibana health:"
curl -s -I http://localhost:5601 | head -n 1 || echo "Kibana not ready"

echo "Jenkins health:"
curl -s -I http://localhost:8080 | head -n 1 || echo "Jenkins not ready"

echo "SonarQube health:"
curl -s -I http://localhost:9000 | head -n 1 || echo "SonarQube not ready"

echo "Tomcat health:"
curl -s -I http://localhost:8081 | head -n 1 || echo "Tomcat not ready"

# Create summary file
echo "=== Installation Summary ==="
cat > /opt/devops/installation-summary.txt <<EOF
DevOps CI/CD Pipeline Installation Complete
==========================================
Installation Date: $(date)
Instance: $INSTANCE_NAME
Environment: $ENVIRONMENT
Project: $PROJECT_NAME

Service URLs:
- Jenkins: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080
- SonarQube: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9000
- Kibana: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):5601
- Tomcat: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8081
- Elasticsearch: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9200

Default Credentials:
- Jenkins: Check /opt/jenkins/initial-password.txt
- SonarQube: admin/admin
- Tomcat Manager: admin/admin123

Logs Location: /var/log/devops-install.log
EOF

echo "Installation completed at: $(date)"
echo "Summary available at: /opt/devops/installation-summary.txt"

# Final restart of all services to ensure they're running
echo "=== Final Service Restart ==="
docker restart elasticsearch && sleep 30
docker restart kibana && sleep 20
docker restart logstash && sleep 20
docker restart jenkins && sleep 30
docker restart sonarqube && sleep 60
docker restart tomcat && sleep 20

echo "=== All Services Ready ==="