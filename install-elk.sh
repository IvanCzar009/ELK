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
xpack.security.enabled: false
xpack.monitoring.collection.enabled: true
EOF

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
while ! curl -s http://localhost:9200/_cluster/health | grep -q '"status":"green\|yellow"'; do
  echo "Waiting for Elasticsearch to be healthy..."
  sleep 10
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
cat > /opt/elk/logstash/logstash.conf <<EOF
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
EOF

# Install Logstash
echo "Installing Logstash..."
docker run -d \
  --name logstash \
  --network elk-network \
  -p 5044:5044 \
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
curl -s http://localhost:9200/_cluster/health?pretty

echo "Kibana status:"
curl -s http://localhost:5601/api/status | grep -o '"overall":{"level":"[^"]*"}'

echo "=== ELK Stack Installation Complete ==="
echo "Elasticsearch: http://localhost:9200"
echo "Kibana: http://localhost:5601"
echo "Logstash: listening on ports 5044 (beats) and 5000 (tcp/json)"

# Restart services to ensure they are running
echo "Restarting ELK services..."
docker restart elasticsearch
sleep 30
docker restart kibana
docker restart logstash

echo "=== ELK Stack Ready ==="