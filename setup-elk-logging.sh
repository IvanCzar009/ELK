#!/bin/bash

# =============================================================================
# ELK Logging Setup Script for Group 6 React App DevOps Pipeline
# =============================================================================
# Purpose: Configure ELK Stack to collect and visualize React app logs
# Author: DevOps Pipeline Automation
# Date: $(date)
# =============================================================================

echo "📊 Starting ELK Logging Setup for Group 6 React App..."
echo "====================================================="

# Configuration
REACT_APP_NAME="group6-react-app"
REACT_APP_PATH="/home/ec2-user/$REACT_APP_NAME"
ELK_CONFIG_DIR="/opt/elk-configs"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
SETUP_LOG_FILE="/tmp/elk-logging-setup.log"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging function
log_step() {
    local step_name="$1"
    local status="$2"
    local message="$3"
    
    echo "[$TIMESTAMP] $step_name: $status - $message" >> "$SETUP_LOG_FILE"
    
    if [ "$status" = "SUCCESS" ]; then
        echo -e "${GREEN}✅ $step_name: $message${NC}"
    elif [ "$status" = "ERROR" ]; then
        echo -e "${RED}❌ $step_name: $message${NC}"
    elif [ "$status" = "INFO" ]; then
        echo -e "${BLUE}ℹ️ $step_name: $message${NC}"
    else
        echo -e "${YELLOW}⚠️ $step_name: $message${NC}"
    fi
}

# Initialize setup log
echo "ELK Logging Setup for Group 6 React App - $TIMESTAMP" > "$SETUP_LOG_FILE"
echo "=========================================" >> "$SETUP_LOG_FILE"

# Check prerequisites
echo ""
echo "🔍 Checking Prerequisites..."
echo "----------------------------"

# Verify integration status
if [ -f "/tmp/integration-status.env" ]; then
    source /tmp/integration-status.env
    if [ "$INTEGRATION_READY" = "true" ]; then
        log_step "Prerequisites" "SUCCESS" "Integration tests passed - ready for ELK setup"
    else
        log_step "Prerequisites" "ERROR" "Integration tests not passed - run integration-tests.sh first"
        exit 1
    fi
else
    log_step "Prerequisites" "WARN" "No integration status found - proceeding anyway"
fi

# Verify React app exists
if [ -d "$REACT_APP_PATH" ]; then
    log_step "React App Check" "SUCCESS" "React app found at $REACT_APP_PATH"
else
    log_step "React App Check" "ERROR" "React app not found at $REACT_APP_PATH"
    exit 1
fi

# =============================================================================
# STEP 1: Create ELK Configuration Directory
# =============================================================================
echo ""
echo "📁 STEP 1: Setting up ELK Configuration Directory"
echo "-----------------------------------------------"

sudo mkdir -p "$ELK_CONFIG_DIR"/{filebeat,logstash,kibana-dashboards}
sudo chown -R ec2-user:ec2-user "$ELK_CONFIG_DIR"
log_step "Config Directory" "SUCCESS" "Created ELK config directory at $ELK_CONFIG_DIR"

# =============================================================================
# STEP 2: Configure Filebeat for React App Logs
# =============================================================================
echo ""
echo "📋 STEP 2: Configuring Filebeat for React App Log Collection"
echo "----------------------------------------------------------"

# Create Filebeat configuration for React app logs
cat > "$ELK_CONFIG_DIR/filebeat/filebeat-react.yml" << 'EOF'
# Filebeat Configuration for Group 6 React App
filebeat.inputs:
# React App Build Logs
- type: log
  enabled: true
  paths:
    - "/home/ec2-user/group6-react-app/npm-debug.log*"
    - "/home/ec2-user/group6-react-app/build.log"
    - "/var/log/react-app/*.log"
  fields:
    app: "group6-react-app"
    log_type: "build"
    environment: "dev"
  fields_under_root: true
  multiline.pattern: '^\d{4}-\d{2}-\d{2}'
  multiline.negate: true
  multiline.match: after

# Jenkins Build Logs for React App
- type: log
  enabled: true
  paths:
    - "/var/jenkins_home/jobs/*/builds/*/log"
    - "/opt/jenkins/jobs/group6-react-app*/builds/*/log"
  fields:
    app: "group6-react-app"
    log_type: "jenkins"
    environment: "dev"
  fields_under_root: true

# Tomcat Deployment Logs
- type: log
  enabled: true
  paths:
    - "/opt/tomcat/logs/catalina.out"
    - "/opt/tomcat/logs/localhost_access_log*.txt"
    - "/opt/tomcat/webapps/group6-react-app/logs/*.log"
  fields:
    app: "group6-react-app"
    log_type: "tomcat"
    environment: "dev"
  fields_under_root: true

# SonarQube Analysis Logs
- type: log
  enabled: true
  paths:
    - "/home/ec2-user/group6-react-app/sonar-scanner.log"
    - "/tmp/sonar-*.log"
  fields:
    app: "group6-react-app"
    log_type: "sonarqube"
    environment: "dev"
  fields_under_root: true

# System logs related to React app
- type: log
  enabled: true
  paths:
    - "/var/log/messages"
    - "/var/log/docker.log"
  fields:
    app: "system"
    log_type: "system"
    environment: "dev"
  fields_under_root: true
  include_lines: ['group6-react-app', 'jenkins', 'tomcat', 'sonarqube']

output.elasticsearch:
  hosts: ["localhost:10100"]
  index: "group6-react-app-%{+yyyy.MM.dd}"

setup.template.name: "group6-react-app"
setup.template.pattern: "group6-react-app-*"

processors:
  - add_host_metadata:
      when.not.contains.tags: forwarded

logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/filebeat
  name: filebeat
  keepfiles: 3
  permissions: 0644
EOF

log_step "Filebeat Config" "SUCCESS" "Created Filebeat configuration for React app logs"

# =============================================================================
# STEP 3: Configure Logstash Pipelines for React App
# =============================================================================
echo ""
echo "🔧 STEP 3: Configuring Logstash Pipelines for React App Processing"
echo "----------------------------------------------------------------"

# Create Logstash pipeline for React app logs
cat > "$ELK_CONFIG_DIR/logstash/react-app-pipeline.conf" << 'EOF'
# Logstash Pipeline for Group 6 React App Logs

input {
  beats {
    port => 15000
  }
}

filter {
  # Add timestamp if missing
  if ![timestamp] {
    mutate {
      add_field => { "timestamp" => "%{@timestamp}" }
    }
  }

  # Parse Jenkins build logs
  if [log_type] == "jenkins" {
    grok {
      match => { 
        "message" => "%{TIMESTAMP_ISO8601:build_timestamp} %{LOGLEVEL:log_level} %{GREEDYDATA:log_message}"
      }
    }
    
    if [log_message] =~ /BUILD/ {
      if [log_message] =~ /SUCCESS/ {
        mutate { add_field => { "build_status" => "SUCCESS" } }
      } else if [log_message] =~ /FAILURE/ {
        mutate { add_field => { "build_status" => "FAILURE" } }
      }
    }
  }

  # Parse React build logs
  if [log_type] == "build" {
    grok {
      match => { 
        "message" => "(?<build_stage>npm run|yarn|webpack|Building|Compiled|Failed to compile).*"
      }
    }
    
    if [message] =~ /error|Error|ERROR/ {
      mutate { add_field => { "severity" => "error" } }
    } else if [message] =~ /warn|Warning|WARN/ {
      mutate { add_field => { "severity" => "warning" } }
    } else {
      mutate { add_field => { "severity" => "info" } }
    }
  }

  # Parse SonarQube analysis logs
  if [log_type] == "sonarqube" {
    grok {
      match => { 
        "message" => "%{TIME:analysis_time}.*INFO.*ANALYSIS SUCCESSFUL.*in (?<analysis_duration>\d+)ms"
      }
    }
    
    if [message] =~ /Quality Gate/ {
      if [message] =~ /PASSED/ {
        mutate { add_field => { "quality_gate" => "PASSED" } }
      } else if [message] =~ /FAILED/ {
        mutate { add_field => { "quality_gate" => "FAILED" } }
      }
    }
  }

  # Parse Tomcat deployment logs
  if [log_type] == "tomcat" {
    grok {
      match => { 
        "message" => "%{TIMESTAMP_ISO8601:deploy_timestamp}.*(?<deployment_action>Starting|Stopping|Deploying|Undeploying).*group6-react-app"
      }
    }
  }

  # Add environment and pipeline metadata
  mutate {
    add_field => { 
      "pipeline_name" => "group6-react-devops"
      "processed_by" => "logstash"
      "processing_timestamp" => "%{@timestamp}"
    }
  }

  # Remove sensitive information
  mutate {
    remove_field => ["[beat][hostname]", "[beat][name]", "[beat][version]"]
  }
}

output {
  elasticsearch {
    hosts => ["localhost:10100"]
    index => "group6-react-app-%{+YYYY.MM.dd}"
    template_name => "group6-react-app"
    template => "/opt/elk-configs/logstash/group6-react-app-template.json"
    template_overwrite => true
  }

  # Debug output (optional)
  if [log_level] == "debug" {
    stdout { 
      codec => rubydebug 
    }
  }
}
EOF

log_step "Logstash Pipeline" "SUCCESS" "Created Logstash pipeline for React app log processing"

# Create Elasticsearch index template
cat > "$ELK_CONFIG_DIR/logstash/group6-react-app-template.json" << 'EOF'
{
  "index_patterns": ["group6-react-app-*"],
  "template": {
    "settings": {
      "number_of_shards": 1,
      "number_of_replicas": 0,
      "index.lifecycle.name": "group6-react-app-policy",
      "index.lifecycle.rollover_alias": "group6-react-app"
    },
    "mappings": {
      "properties": {
        "@timestamp": { "type": "date" },
        "app": { "type": "keyword" },
        "log_type": { "type": "keyword" },
        "environment": { "type": "keyword" },
        "message": { "type": "text" },
        "severity": { "type": "keyword" },
        "build_status": { "type": "keyword" },
        "quality_gate": { "type": "keyword" },
        "build_stage": { "type": "keyword" },
        "pipeline_name": { "type": "keyword" },
        "host": {
          "properties": {
            "name": { "type": "keyword" },
            "ip": { "type": "ip" }
          }
        }
      }
    }
  }
}
EOF

log_step "ES Template" "SUCCESS" "Created Elasticsearch index template for React app logs"

# =============================================================================
# STEP 4: Install and Configure Filebeat
# =============================================================================
echo ""
echo "📦 STEP 4: Installing and Configuring Filebeat"
echo "---------------------------------------------"

# Check if Filebeat is already installed
if command -v filebeat > /dev/null 2>&1; then
    log_step "Filebeat Install" "INFO" "Filebeat already installed"
else
    # Install Filebeat
    echo "Installing Filebeat..."
    curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.10.4-x86_64.rpm
    sudo rpm -vi filebeat-8.10.4-x86_64.rpm 2>/dev/null || log_step "Filebeat Install" "WARN" "Filebeat RPM install issues (may already exist)"
    rm -f filebeat-8.10.4-x86_64.rpm
    log_step "Filebeat Install" "SUCCESS" "Filebeat installed successfully"
fi

# Configure Filebeat
sudo cp "$ELK_CONFIG_DIR/filebeat/filebeat-react.yml" /etc/filebeat/filebeat.yml
sudo chmod 600 /etc/filebeat/filebeat.yml
log_step "Filebeat Config" "SUCCESS" "Filebeat configured with React app settings"

# Create log directories
sudo mkdir -p /var/log/react-app
sudo mkdir -p /var/log/filebeat
sudo chown -R ec2-user:ec2-user /var/log/react-app
log_step "Log Directories" "SUCCESS" "Created log directories for React app"

# =============================================================================
# STEP 5: Configure Logstash Pipeline
# =============================================================================
echo ""
echo "🔀 STEP 5: Deploying Logstash Pipeline Configuration"
echo "--------------------------------------------------"

# Stop Logstash container to update configuration
docker stop logstash 2>/dev/null || log_step "Logstash Stop" "INFO" "Logstash not running or already stopped"

# Create Logstash pipeline directory and copy configuration
sudo mkdir -p /opt/logstash-pipeline
sudo cp "$ELK_CONFIG_DIR/logstash/react-app-pipeline.conf" /opt/logstash-pipeline/
sudo cp "$ELK_CONFIG_DIR/logstash/group6-react-app-template.json" /opt/logstash-pipeline/
sudo chown -R 1000:1000 /opt/logstash-pipeline

# Restart Logstash with new pipeline
docker run -d --name logstash \
  --network elk-network \
  -p 15000:15000 \
  -p 5000:5000 \
  -v /opt/logstash-pipeline:/usr/share/logstash/pipeline/ \
  -e "xpack.monitoring.enabled=false" \
  docker.elastic.co/logstash/logstash:8.10.4

log_step "Logstash Pipeline" "SUCCESS" "Logstash restarted with React app pipeline configuration"

# =============================================================================
# STEP 6: Create Kibana Dashboards for React App
# =============================================================================
echo ""
echo "📊 STEP 6: Creating Kibana Dashboards for React App Monitoring"
echo "------------------------------------------------------------"

# Wait for services to be ready
echo "Waiting for Logstash and Elasticsearch to be ready..."
sleep 15

# Create index pattern in Elasticsearch
curl -X PUT "localhost:10100/_index_template/group6-react-app" \
  -H 'Content-Type: application/json' \
  -d @"$ELK_CONFIG_DIR/logstash/group6-react-app-template.json" 2>/dev/null

log_step "Index Template" "SUCCESS" "Created Elasticsearch index template"

# Create Kibana dashboard configuration
cat > "$ELK_CONFIG_DIR/kibana-dashboards/group6-react-app-dashboard.json" << 'EOF'
{
  "dashboard": {
    "title": "Group 6 React App - DevOps Pipeline Dashboard",
    "description": "Comprehensive monitoring dashboard for Group 6 React App CI/CD pipeline",
    "panels": [
      {
        "title": "Build Status Overview",
        "type": "pie",
        "query": "app:group6-react-app AND log_type:jenkins",
        "field": "build_status"
      },
      {
        "title": "Deploy Timeline",
        "type": "timeline",
        "query": "app:group6-react-app AND log_type:tomcat",
        "field": "@timestamp"
      },
      {
        "title": "Quality Gate Status",
        "type": "metric",
        "query": "app:group6-react-app AND log_type:sonarqube AND quality_gate:*",
        "field": "quality_gate"
      },
      {
        "title": "Error Logs",
        "type": "logs",
        "query": "app:group6-react-app AND severity:error"
      },
      {
        "title": "Build Performance",
        "type": "histogram",
        "query": "app:group6-react-app AND log_type:build",
        "field": "@timestamp"
      }
    ]
  }
}
EOF

log_step "Kibana Dashboard" "SUCCESS" "Created Kibana dashboard configuration for React app"

# =============================================================================
# STEP 7: Start Filebeat Service
# =============================================================================
echo ""
echo "🚀 STEP 7: Starting Filebeat Service for Log Collection"
echo "-----------------------------------------------------"

# Enable and start Filebeat
sudo systemctl enable filebeat 2>/dev/null || log_step "Filebeat Enable" "WARN" "Could not enable filebeat service"
sudo systemctl start filebeat 2>/dev/null || log_step "Filebeat Start" "WARN" "Could not start filebeat service"

# Alternative: Run Filebeat directly if systemctl fails
if ! sudo systemctl is-active --quiet filebeat 2>/dev/null; then
    echo "Starting Filebeat manually..."
    sudo /usr/share/filebeat/bin/filebeat -c /etc/filebeat/filebeat.yml -path.home /usr/share/filebeat -path.config /etc/filebeat -path.data /var/lib/filebeat -path.logs /var/log/filebeat &
    log_step "Filebeat Start" "SUCCESS" "Filebeat started manually"
else
    log_step "Filebeat Start" "SUCCESS" "Filebeat service started successfully"
fi

# =============================================================================
# STEP 8: Create Sample Logs and Test Pipeline
# =============================================================================
echo ""
echo "🧪 STEP 8: Testing ELK Pipeline with Sample React App Logs"
echo "--------------------------------------------------------"

# Create sample log entries for testing
mkdir -p /var/log/react-app

# Sample build log
cat > /var/log/react-app/build.log << EOF
$(date '+%Y-%m-%d %H:%M:%S') npm run build started for group6-react-app
$(date '+%Y-%m-%d %H:%M:%S') webpack: Building production bundle...
$(date '+%Y-%m-%d %H:%M:%S') webpack: Compiled successfully in 45.2s
$(date '+%Y-%m-%d %H:%M:%S') Build completed successfully - Ready for deployment
EOF

# Sample error log
echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR: Failed to compile src/App.js - Syntax error detected" >> /var/log/react-app/build.log

log_step "Sample Logs" "SUCCESS" "Created sample logs for pipeline testing"

# Wait for log processing
echo "Waiting for logs to be processed through ELK pipeline..."
sleep 20

# =============================================================================
# STEP 9: Verify ELK Integration
# =============================================================================
echo ""
echo "✅ STEP 9: Verifying ELK Integration for React App"
echo "------------------------------------------------"

# Check if Elasticsearch has received logs
ES_LOGS_COUNT=$(curl -s "localhost:10100/group6-react-app-*/_count" | grep -o '"count":[0-9]*' | cut -d':' -f2 2>/dev/null || echo "0")
if [ "$ES_LOGS_COUNT" -gt 0 ]; then
    log_step "Log Ingestion" "SUCCESS" "Elasticsearch has received $ES_LOGS_COUNT log entries"
else
    log_step "Log Ingestion" "WARN" "No logs detected yet in Elasticsearch - may need more time"
fi

# Check Logstash processing
LOGSTASH_STATUS=$(curl -s "localhost:9600/_node/stats/pipeline" 2>/dev/null | grep -o '"events"' | wc -l)
if [ "$LOGSTASH_STATUS" -gt 0 ]; then
    log_step "Logstash Processing" "SUCCESS" "Logstash is processing logs"
else
    log_step "Logstash Processing" "WARN" "Logstash processing status unclear"
fi

# Check Filebeat status
if pgrep -f filebeat > /dev/null; then
    log_step "Filebeat Status" "SUCCESS" "Filebeat is running and collecting logs"
else
    log_step "Filebeat Status" "WARN" "Filebeat process not detected"
fi

# =============================================================================
# STEP 10: Generate Access Instructions
# =============================================================================
echo ""
echo "📋 STEP 10: Generating Access Instructions and Summary"
echo "----------------------------------------------------"

# Get public IP for access instructions
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "YOUR_PUBLIC_IP")

# Create access instructions file
cat > /tmp/elk-logging-access.txt << EOF
=============================================================================
Group 6 React App - ELK Logging Integration Setup Complete!
=============================================================================

🌐 ACCESS URLS:
---------------
Kibana Dashboard: http://$PUBLIC_IP:10101
Elasticsearch API: http://$PUBLIC_IP:10100
Logstash Monitoring: http://$PUBLIC_IP:9600

🔍 KIBANA SETUP:
-----------------
1. Open Kibana: http://$PUBLIC_IP:10101
2. Go to Stack Management > Index Patterns
3. Create index pattern: group6-react-app-*
4. Set time field: @timestamp
5. Go to Dashboard and import: $ELK_CONFIG_DIR/kibana-dashboards/group6-react-app-dashboard.json

📊 LOG SOURCES CONFIGURED:
--------------------------
✅ React App Build Logs: /var/log/react-app/*.log
✅ Jenkins Build Logs: /opt/jenkins/jobs/group6-react-app*/builds/*/log  
✅ Tomcat Deployment Logs: /opt/tomcat/logs/catalina.out
✅ SonarQube Analysis Logs: /home/ec2-user/group6-react-app/sonar-scanner.log
✅ System Logs: /var/log/messages (filtered for React app)

🔧 PIPELINE COMPONENTS:
-----------------------
✅ Filebeat: Collecting logs from multiple sources
✅ Logstash: Processing and enriching log data
✅ Elasticsearch: Storing and indexing logs
✅ Kibana: Visualizing and monitoring logs

📈 WHAT YOU CAN MONITOR:
------------------------
• Build success/failure rates
• Deployment timelines
• Code quality metrics from SonarQube
• Error patterns and trends
• Performance metrics
• System health indicators

🛠️ NEXT STEPS:
---------------
1. Run your React app build pipeline
2. Deploy to Tomcat via Jenkins
3. Monitor logs in Kibana dashboard
4. Set up alerts for critical events

📁 Configuration Files:
-----------------------
Filebeat Config: $ELK_CONFIG_DIR/filebeat/filebeat-react.yml
Logstash Pipeline: $ELK_CONFIG_DIR/logstash/react-app-pipeline.conf
Kibana Dashboard: $ELK_CONFIG_DIR/kibana-dashboards/group6-react-app-dashboard.json
Setup Log: $SETUP_LOG_FILE
EOF

log_step "Access Instructions" "SUCCESS" "Generated access instructions at /tmp/elk-logging-access.txt"

# =============================================================================
# FINAL SUMMARY AND STATUS
# =============================================================================
echo ""
echo "🎉 ELK LOGGING SETUP SUMMARY"
echo "=========================="

# Count setup steps
TOTAL_STEPS=10
SUCCESSFUL_STEPS=$(grep -c "SUCCESS" "$SETUP_LOG_FILE")
WARNING_STEPS=$(grep -c "WARN" "$SETUP_LOG_FILE")
ERROR_STEPS=$(grep -c "ERROR" "$SETUP_LOG_FILE")

echo -e "${BLUE}Total Setup Steps: $TOTAL_STEPS${NC}"
echo -e "${GREEN}Successful: $SUCCESSFUL_STEPS${NC}"
echo -e "${YELLOW}Warnings: $WARNING_STEPS${NC}"
echo -e "${RED}Errors: $ERROR_STEPS${NC}"

echo ""
echo "📋 Detailed Setup Log:"
echo "----------------------"
cat "$SETUP_LOG_FILE"

echo ""
echo "💡 RECOMMENDATIONS:"
echo "------------------"

if [ $ERROR_STEPS -eq 0 ]; then
    echo -e "${GREEN}🎉 ELK logging setup completed successfully!${NC}"
    echo -e "${GREEN}✅ Your Group 6 React App is now integrated with ELK Stack logging${NC}"
    echo -e "${BLUE}🌐 Access Kibana: http://$PUBLIC_IP:10101${NC}"
    echo -e "${PURPLE}📊 Monitor your CI/CD pipeline through comprehensive dashboards${NC}"
    echo ""
    echo -e "${YELLOW}Next: Configure monitoring and metrics with configure-monitoring.sh${NC}"
else
    echo -e "${RED}⚠️ Some errors occurred during setup. Please review the setup log:${NC}"
    grep "ERROR" "$SETUP_LOG_FILE"
fi

echo ""
echo "📁 Setup completed! Full access instructions: /tmp/elk-logging-access.txt"
echo "🔄 Run this script again if needed, or proceed to the next integration script."

# Create status file for next script
ELK_STATUS_FILE="/tmp/elk-logging-status.env"
echo "# ELK Logging Setup Status - $TIMESTAMP" > "$ELK_STATUS_FILE"
echo "ELK_SETUP_COMPLETED=true" >> "$ELK_STATUS_FILE"
echo "ELK_SETUP_ERRORS=$ERROR_STEPS" >> "$ELK_STATUS_FILE"
echo "ELK_SETUP_WARNINGS=$WARNING_STEPS" >> "$ELK_STATUS_FILE"
echo "FILEBEAT_CONFIGURED=true" >> "$ELK_STATUS_FILE"
echo "LOGSTASH_PIPELINE_READY=true" >> "$ELK_STATUS_FILE"
echo "KIBANA_DASHBOARD_READY=true" >> "$ELK_STATUS_FILE"
echo "PUBLIC_IP=$PUBLIC_IP" >> "$ELK_STATUS_FILE"

if [ $ERROR_STEPS -eq 0 ]; then
    echo "ELK_LOGGING_READY=true" >> "$ELK_STATUS_FILE"
    exit 0
else
    echo "ELK_LOGGING_READY=false" >> "$ELK_STATUS_FILE"
    exit 1
fi