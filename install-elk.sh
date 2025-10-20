#!/bin/bash
# install-elk.sh - Script to install Elasticsearch, Logstash, and Kibana using Docker

echo "=== Starting ELK Stack Installation ==="

# Create ELK network
echo "Creating ELK Docker network..."
docker network create elk-network

# Create directories for ELK data persistence
echo "Creating ELK data directories..."
sudo mkdir -p /opt/elk/elasticsearch/data
sudo mkdir -p /opt/elk/logstash/config
sudo mkdir -p /opt/elk/kibana/config
sudo chown -R 1000:1000 /opt/elk/

# Create Elasticsearch configuration
echo "Creating Elasticsearch configuration..."
cat > /opt/elk/elasticsearch/elasticsearch.yml <<EOF
cluster.name: "docker-cluster"
network.host: 0.0.0.0
discovery.type: single-node
xpack.security.enabled: true
xpack.security.transport.ssl.enabled: false
xpack.security.http.ssl.enabled: false
xpack.security.authc.password_hashing.algorithm: bcrypt
xpack.monitoring.collection.enabled: true
# Enable built-in users
xpack.security.authc.realms.native.native1.order: 0
EOF

# Set default credentials
export ELASTIC_USERNAME="elastic"
export ELASTIC_PASSWORD="elastic123"
export KIBANA_USERNAME="kibana_admin"
export KIBANA_PASSWORD="kibana123"

# Install Elasticsearch
echo "Installing Elasticsearch..."
docker run -d \
  --name elasticsearch \
  --network elk-network \
  -p 10100:9200 \
  -p 9300:9300 \
  -e "discovery.type=single-node" \
  -e "ES_JAVA_OPTS=-Xms512m -Xmx512m" \
  -e "ELASTIC_PASSWORD=${ELASTIC_PASSWORD}" \
  -v /opt/elk/elasticsearch/data:/usr/share/elasticsearch/data \
  -v /opt/elk/elasticsearch/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml \
  docker.elastic.co/elasticsearch/elasticsearch:8.10.4

# Wait for Elasticsearch to be ready
echo "Waiting for Elasticsearch to start..."
sleep 60

# Wait for Elasticsearch to be healthy
while ! curl -s -u "elastic:${ELASTIC_PASSWORD}" http://localhost:10100/_cluster/health | grep -q '"status":"green\|yellow"'; do
  echo "Waiting for Elasticsearch to be ready..."
  sleep 10
done

echo "Setting up Elasticsearch built-in users..."
# Reset built-in user passwords
docker exec elasticsearch /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic -p ${ELASTIC_PASSWORD} --batch --silent || true
docker exec elasticsearch /usr/share/elasticsearch/bin/elasticsearch-reset-password -u kibana_system -p kibana_system123 --batch --silent || true

echo "Elasticsearch is ready with authentication!"

# Setup Elasticsearch security
echo "Setting up Elasticsearch built-in users..."
# Wait for security to be fully initialized
sleep 15

# The ELASTIC_PASSWORD environment variable sets the elastic user password
echo "Elasticsearch security configured!"
echo "Default credentials:"
echo "  elastic: elasticsearch123"
echo "  kibana_system: kibana123"

# Save credentials to file for reference
echo "elastic:elasticsearch123" > /opt/elk/elastic-credentials.txt
echo "kibana_system:kibana123" >> /opt/elk/elastic-credentials.txt
chown 1000:1000 /opt/elk/elastic-credentials.txt

# Install Kibana
echo "Installing Kibana..."
# Install Kibana
echo "Installing Kibana with authentication..."

# Create Kibana configuration
cat > /opt/elk/kibana/kibana.yml <<EOF
server.host: "0.0.0.0"
server.port: 5601
server.name: "kibana-server"
elasticsearch.hosts: ["http://elasticsearch:9200"]
elasticsearch.username: "kibana_system"
elasticsearch.password: "kibana_system123"
xpack.security.enabled: true
xpack.security.session.idleTimeout: "1h"
xpack.security.session.lifespan: "30d"
xpack.encryptedSavedObjects.encryptionKey: "a7a6311933d3503b89bc2dbc36572c33a7a6311933d3503b"
logging.appenders.file.type: file
logging.appenders.file.fileName: /usr/share/kibana/logs/kibana.log
logging.appenders.file.layout.type: json
logging.root.appenders: [default, file]
logging.root.level: info
EOF

docker run -d \
  --name kibana \
  --network elk-network \
  -p 10101:5601 \
  -e "ELASTICSEARCH_HOSTS=http://elasticsearch:9200" \
  -e "ELASTICSEARCH_USERNAME=kibana_system" \
  -e "ELASTICSEARCH_PASSWORD=kibana_system123" \
  -v /opt/elk/kibana/kibana.yml:/usr/share/kibana/config/kibana.yml \
  docker.elastic.co/kibana/kibana:8.10.4

# Wait for Kibana to be ready
echo "Waiting for Kibana to start..."
sleep 60

# Create Kibana user for admin access
echo "Creating Kibana admin user..."
# Create a role for Kibana admin
curl -X POST "localhost:10100/_security/role/kibana_admin_role" \
  -u "elastic:${ELASTIC_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{
    "cluster": ["all"],
    "indices": [
      {
        "names": ["*"],
        "privileges": ["all"]
      }
    ],
    "applications": [
      {
        "application": "kibana-.kibana",
        "privileges": ["all"],
        "resources": ["*"]
      }
    ]
  }' || echo "Role creation may have failed, continuing..."

# Create Kibana admin user
curl -X POST "localhost:10100/_security/user/${KIBANA_USERNAME}" \
  -u "elastic:${ELASTIC_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d "{
    \"password\": \"${KIBANA_PASSWORD}\",
    \"roles\": [\"kibana_admin_role\", \"superuser\"],
    \"full_name\": \"Kibana Administrator\",
    \"email\": \"kibana@example.com\"
  }" || echo "User creation may have failed, continuing..."

echo "Kibana authentication configured!"
echo "Kibana Login: ${KIBANA_USERNAME} / ${KIBANA_PASSWORD}"

# Create Logstash configuration
echo "Creating Logstash configuration..."
cat > /opt/elk/logstash/logstash.conf <<EOF
input {
  beats {
    port => 15000
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
EOF

# Install Logstash
echo "Installing Logstash..."
docker run -d \
  --name logstash \
  --network elk-network \
  -p 15000:15000 \
  -p 5000:5000 \
  -v /opt/elk/logstash/logstash.conf:/usr/share/logstash/pipeline/logstash.conf \
  docker.elastic.co/logstash/logstash:8.10.4

# Wait for services to be ready
echo "Waiting for all ELK services to be ready..."
sleep 120

# Check service status
echo "Checking ELK Stack status..."
docker ps | grep -E "(elasticsearch|kibana|logstash)"

# Health checks
echo "=== ELK Stack Health Checks ==="
echo "Elasticsearch health:"
curl -s -u "elastic:${ELASTIC_PASSWORD}" http://localhost:10100/_cluster/health?pretty

echo "Kibana status:"
curl -s -u "${KIBANA_USERNAME}:${KIBANA_PASSWORD}" http://localhost:10101/api/status | grep -o '"overall":{"level":"[^"]*"}' || echo "Kibana authentication required"

echo "=== ELK Stack Installation Complete ==="
echo "Elasticsearch: http://localhost:10100 (User: elastic / Password: ${ELASTIC_PASSWORD})"
echo "Kibana: http://localhost:10101 (User: ${KIBANA_USERNAME} / Password: ${KIBANA_PASSWORD})"
echo "Logstash: listening on ports 15000 (beats) and 5000 (tcp/json)"

# Save credentials to file
echo "=== Saving Authentication Credentials ==="
cat > /opt/elk/kibana-credentials.txt <<EOF
# ELK Stack Authentication Credentials
# Generated on: $(date)

# Elasticsearch Super User
elasticsearch_user=elastic
elasticsearch_password=${ELASTIC_PASSWORD}

# Kibana Admin User  
kibana_user=${KIBANA_USERNAME}
kibana_password=${KIBANA_PASSWORD}

# Kibana System User (for internal communication)
kibana_system_user=kibana_system
kibana_system_password=kibana_system123

# Access URLs
elasticsearch_url=http://localhost:10100
kibana_url=http://localhost:10101
EOF

chown ec2-user:ec2-user /opt/elk/kibana-credentials.txt
chmod 600 /opt/elk/kibana-credentials.txt

echo "Credentials saved to: /opt/elk/kibana-credentials.txt"

# Restart services to ensure they are running
echo "Restarting ELK services..."
docker restart elasticsearch
sleep 30
docker restart kibana
docker restart logstash

echo "=== ELK Stack Ready ==="