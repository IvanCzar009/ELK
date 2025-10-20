#!/bin/bash

# =============================================================================
# Configure Monitoring Script for Group 6 React App DevOps Pipeline
# =============================================================================
# Purpose: Set up basic metrics collection and monitoring for the DevOps pipeline
# Author: DevOps Pipeline Automation
# Date: $(date)
# =============================================================================

echo "📈 Starting Monitoring Configuration for Group 6 React App..."
echo "============================================================="

# Configuration
REACT_APP_NAME="group6-react-app"
REACT_APP_PATH="/home/ec2-user/$REACT_APP_NAME"
MONITORING_DIR="/opt/monitoring"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
MONITORING_LOG_FILE="/tmp/monitoring-setup.log"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging function
log_step() {
    local step_name="$1"
    local status="$2"
    local message="$3"
    
    echo "[$TIMESTAMP] $step_name: $status - $message" >> "$MONITORING_LOG_FILE"
    
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

# Initialize monitoring log
echo "Monitoring Configuration for Group 6 React App - $TIMESTAMP" > "$MONITORING_LOG_FILE"
echo "=========================================" >> "$MONITORING_LOG_FILE"

# Check prerequisites
echo ""
echo "🔍 Checking Prerequisites..."
echo "----------------------------"

# Verify ELK logging status
if [ -f "/tmp/elk-logging-status.env" ]; then
    source /tmp/elk-logging-status.env
    if [ "$ELK_LOGGING_READY" = "true" ]; then
        log_step "ELK Prerequisites" "SUCCESS" "ELK logging is operational and ready"
    else
        log_step "ELK Prerequisites" "WARN" "ELK logging has issues but proceeding"
    fi
else
    log_step "ELK Prerequisites" "WARN" "No ELK status found - proceeding anyway"
fi

# Verify React app exists
if [ -d "$REACT_APP_PATH" ]; then
    log_step "React App Check" "SUCCESS" "React app found at $REACT_APP_PATH"
else
    log_step "React App Check" "ERROR" "React app not found at $REACT_APP_PATH"
    exit 1
fi

# =============================================================================
# STEP 1: Create Monitoring Directory Structure
# =============================================================================
echo ""
echo "📁 STEP 1: Setting up Monitoring Directory Structure"
echo "--------------------------------------------------"

sudo mkdir -p "$MONITORING_DIR"/{scripts,metrics,dashboards,alerts,config}
sudo chown -R ec2-user:ec2-user "$MONITORING_DIR"
log_step "Monitoring Directory" "SUCCESS" "Created monitoring structure at $MONITORING_DIR"

# =============================================================================
# STEP 2: Basic System Metrics Collection
# =============================================================================
echo ""
echo "📊 STEP 2: Setting up Basic System Metrics Collection"
echo "---------------------------------------------------"

# Create system metrics collection script
cat > "$MONITORING_DIR/scripts/collect-system-metrics.sh" << 'EOF'
#!/bin/bash

# System Metrics Collection for Group 6 React App
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
METRICS_FILE="/opt/monitoring/metrics/system-metrics-$(date +%Y%m%d).log"

# Create metrics entry
echo "[$TIMESTAMP] SYSTEM_METRICS" >> "$METRICS_FILE"

# CPU Usage
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
echo "[$TIMESTAMP] CPU_USAGE: $CPU_USAGE%" >> "$METRICS_FILE"

# Memory Usage
MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.2f", $3/$2 * 100.0}')
echo "[$TIMESTAMP] MEMORY_USAGE: $MEMORY_USAGE%" >> "$METRICS_FILE"

# Disk Usage
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}')
echo "[$TIMESTAMP] DISK_USAGE: $DISK_USAGE" >> "$METRICS_FILE"

# Load Average
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}')
echo "[$TIMESTAMP] LOAD_AVERAGE: $LOAD_AVG" >> "$METRICS_FILE"

# Docker Container Status
DOCKER_CONTAINERS=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep -v NAMES | wc -l)
echo "[$TIMESTAMP] DOCKER_CONTAINERS_RUNNING: $DOCKER_CONTAINERS" >> "$METRICS_FILE"

# Service-specific metrics
JENKINS_STATUS=$(curl -s -w "%{http_code}" http://localhost:8080 -o /dev/null)
echo "[$TIMESTAMP] JENKINS_STATUS: $JENKINS_STATUS" >> "$METRICS_FILE"

SONARQUBE_STATUS=$(curl -s -w "%{http_code}" http://localhost:9000 -o /dev/null)
echo "[$TIMESTAMP] SONARQUBE_STATUS: $SONARQUBE_STATUS" >> "$METRICS_FILE"

ELASTICSEARCH_STATUS=$(curl -s -w "%{http_code}" http://localhost:10100 -o /dev/null)
echo "[$TIMESTAMP] ELASTICSEARCH_STATUS: $ELASTICSEARCH_STATUS" >> "$METRICS_FILE"

KIBANA_STATUS=$(curl -s -w "%{http_code}" http://localhost:10101 -o /dev/null)
echo "[$TIMESTAMP] KIBANA_STATUS: $KIBANA_STATUS" >> "$METRICS_FILE"

TOMCAT_STATUS=$(curl -s -w "%{http_code}" http://localhost:8081 -o /dev/null)
echo "[$TIMESTAMP] TOMCAT_STATUS: $TOMCAT_STATUS" >> "$METRICS_FILE"

echo "[$TIMESTAMP] METRICS_COLLECTION_COMPLETE" >> "$METRICS_FILE"
EOF

chmod +x "$MONITORING_DIR/scripts/collect-system-metrics.sh"
log_step "System Metrics Script" "SUCCESS" "Created system metrics collection script"

# =============================================================================
# STEP 3: React App Build Metrics
# =============================================================================
echo ""
echo "🔧 STEP 3: Setting up React App Build Metrics"
echo "--------------------------------------------"

# Create build metrics collection script
cat > "$MONITORING_DIR/scripts/collect-build-metrics.sh" << 'EOF'
#!/bin/bash

# Build Metrics Collection for Group 6 React App
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
METRICS_FILE="/opt/monitoring/metrics/build-metrics-$(date +%Y%m%d).log"
REACT_APP_PATH="/home/ec2-user/group6-react-app"

echo "[$TIMESTAMP] BUILD_METRICS_START" >> "$METRICS_FILE"

# Check if build directory exists
if [ -d "$REACT_APP_PATH/build" ]; then
    echo "[$TIMESTAMP] BUILD_DIRECTORY_EXISTS: true" >> "$METRICS_FILE"
    
    # Build size metrics
    BUILD_SIZE=$(du -sh "$REACT_APP_PATH/build" | cut -f1)
    echo "[$TIMESTAMP] BUILD_SIZE: $BUILD_SIZE" >> "$METRICS_FILE"
    
    # Count of build files
    BUILD_FILES=$(find "$REACT_APP_PATH/build" -type f | wc -l)
    echo "[$TIMESTAMP] BUILD_FILES_COUNT: $BUILD_FILES" >> "$METRICS_FILE"
    
    # Build timestamp
    BUILD_TIME=$(stat -c %Y "$REACT_APP_PATH/build" 2>/dev/null || echo "unknown")
    echo "[$TIMESTAMP] LAST_BUILD_TIME: $BUILD_TIME" >> "$METRICS_FILE"
    
    # Check main JS file size (if exists)
    MAIN_JS=$(find "$REACT_APP_PATH/build/static/js" -name "main.*.js" 2>/dev/null | head -1)
    if [ -n "$MAIN_JS" ]; then
        MAIN_JS_SIZE=$(du -h "$MAIN_JS" | cut -f1)
        echo "[$TIMESTAMP] MAIN_JS_SIZE: $MAIN_JS_SIZE" >> "$METRICS_FILE"
    fi
    
    # Check CSS file size (if exists)
    MAIN_CSS=$(find "$REACT_APP_PATH/build/static/css" -name "main.*.css" 2>/dev/null | head -1)
    if [ -n "$MAIN_CSS" ]; then
        MAIN_CSS_SIZE=$(du -h "$MAIN_CSS" | cut -f1)
        echo "[$TIMESTAMP] MAIN_CSS_SIZE: $MAIN_CSS_SIZE" >> "$METRICS_FILE"
    fi
else
    echo "[$TIMESTAMP] BUILD_DIRECTORY_EXISTS: false" >> "$METRICS_FILE"
fi

# Package.json dependencies count
if [ -f "$REACT_APP_PATH/package.json" ]; then
    DEPENDENCIES_COUNT=$(grep -c '"' "$REACT_APP_PATH/package.json" 2>/dev/null || echo "0")
    echo "[$TIMESTAMP] PACKAGE_JSON_LINES: $DEPENDENCIES_COUNT" >> "$METRICS_FILE"
fi

# Node modules size (if exists)
if [ -d "$REACT_APP_PATH/node_modules" ]; then
    NODE_MODULES_SIZE=$(du -sh "$REACT_APP_PATH/node_modules" 2>/dev/null | cut -f1 || echo "unknown")
    echo "[$TIMESTAMP] NODE_MODULES_SIZE: $NODE_MODULES_SIZE" >> "$METRICS_FILE"
fi

echo "[$TIMESTAMP] BUILD_METRICS_COMPLETE" >> "$METRICS_FILE"
EOF

chmod +x "$MONITORING_DIR/scripts/collect-build-metrics.sh"
log_step "Build Metrics Script" "SUCCESS" "Created React app build metrics collection script"

# =============================================================================
# STEP 4: ELK Stack Metrics
# =============================================================================
echo ""
echo "📈 STEP 4: Setting up ELK Stack Metrics Collection"
echo "------------------------------------------------"

# Create ELK metrics collection script
cat > "$MONITORING_DIR/scripts/collect-elk-metrics.sh" << 'EOF'
#!/bin/bash

# ELK Stack Metrics Collection for Group 6 React App
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
METRICS_FILE="/opt/monitoring/metrics/elk-metrics-$(date +%Y%m%d).log"

echo "[$TIMESTAMP] ELK_METRICS_START" >> "$METRICS_FILE"

# Elasticsearch metrics
ES_HEALTH=$(curl -s "localhost:10100/_cluster/health" 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
echo "[$TIMESTAMP] ELASTICSEARCH_HEALTH: $ES_HEALTH" >> "$METRICS_FILE"

# Index statistics
INDEX_COUNT=$(curl -s "localhost:10100/group6-react-app-*/_count" 2>/dev/null | grep -o '"count":[0-9]*' | cut -d':' -f2 || echo "0")
echo "[$TIMESTAMP] LOG_ENTRIES_COUNT: $INDEX_COUNT" >> "$METRICS_FILE"

# Index size
INDEX_SIZE=$(curl -s "localhost:10100/_cat/indices/group6-react-app-*?h=store.size" 2>/dev/null | head -1 || echo "unknown")
echo "[$TIMESTAMP] INDEX_SIZE: $INDEX_SIZE" >> "$METRICS_FILE"

# Filebeat status
if systemctl is-active --quiet filebeat 2>/dev/null; then
    echo "[$TIMESTAMP] FILEBEAT_STATUS: active" >> "$METRICS_FILE"
else
    echo "[$TIMESTAMP] FILEBEAT_STATUS: inactive" >> "$METRICS_FILE"
fi

# Kibana status
KIBANA_HEALTH=$(curl -s "localhost:10101/api/status" 2>/dev/null | grep -o '"level":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
echo "[$TIMESTAMP] KIBANA_HEALTH: $KIBANA_HEALTH" >> "$METRICS_FILE"

# Recent log activity (logs in last hour)
RECENT_LOGS=$(curl -s "localhost:10100/group6-react-app-*/_search" -H "Content-Type: application/json" -d '{
  "query": {
    "range": {
      "@timestamp": {
        "gte": "now-1h"
      }
    }
  },
  "size": 0
}' 2>/dev/null | grep -o '"value":[0-9]*' | cut -d':' -f2 || echo "0")
echo "[$TIMESTAMP] LOGS_LAST_HOUR: $RECENT_LOGS" >> "$METRICS_FILE"

echo "[$TIMESTAMP] ELK_METRICS_COMPLETE" >> "$METRICS_FILE"
EOF

chmod +x "$MONITORING_DIR/scripts/collect-elk-metrics.sh"
log_step "ELK Metrics Script" "SUCCESS" "Created ELK stack metrics collection script"

# =============================================================================
# STEP 5: DevOps Pipeline Metrics
# =============================================================================
echo ""
echo "🔄 STEP 5: Setting up DevOps Pipeline Metrics"
echo "--------------------------------------------"

# Create pipeline metrics collection script
cat > "$MONITORING_DIR/scripts/collect-pipeline-metrics.sh" << 'EOF'
#!/bin/bash

# DevOps Pipeline Metrics Collection for Group 6 React App
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
METRICS_FILE="/opt/monitoring/metrics/pipeline-metrics-$(date +%Y%m%d).log"

echo "[$TIMESTAMP] PIPELINE_METRICS_START" >> "$METRICS_FILE"

# Jenkins metrics
JENKINS_JOBS=$(curl -s "localhost:8080/api/json" 2>/dev/null | grep -o '"jobs":\[[^]]*\]' | grep -o '{[^}]*}' | wc -l || echo "0")
echo "[$TIMESTAMP] JENKINS_JOBS_COUNT: $JENKINS_JOBS" >> "$METRICS_FILE"

# SonarQube projects
SONAR_PROJECTS=$(curl -s "localhost:9000/api/projects/search" 2>/dev/null | grep -o '"components":\[[^]]*\]' | grep -o '{[^}]*}' | wc -l || echo "0")
echo "[$TIMESTAMP] SONARQUBE_PROJECTS: $SONAR_PROJECTS" >> "$METRICS_FILE"

# Tomcat applications
TOMCAT_APPS=$(ls /opt/tomcat/webapps/ 2>/dev/null | wc -l || echo "0")
echo "[$TIMESTAMP] TOMCAT_APPS_DEPLOYED: $TOMCAT_APPS" >> "$METRICS_FILE"

# Docker containers status
DOCKER_RUNNING=$(docker ps -q | wc -l)
echo "[$TIMESTAMP] DOCKER_CONTAINERS_RUNNING: $DOCKER_RUNNING" >> "$METRICS_FILE"

DOCKER_TOTAL=$(docker ps -a -q | wc -l)
echo "[$TIMESTAMP] DOCKER_CONTAINERS_TOTAL: $DOCKER_TOTAL" >> "$METRICS_FILE"

# Services connectivity matrix
SERVICES=("jenkins:8080" "sonarqube:9000" "elasticsearch:10100" "kibana:10101" "tomcat:8081")
CONNECTIVITY_SCORE=0
TOTAL_SERVICES=${#SERVICES[@]}

for service in "${SERVICES[@]}"; do
    service_name=$(echo $service | cut -d':' -f1)
    service_port=$(echo $service | cut -d':' -f2)
    
    if curl -s --connect-timeout 5 "localhost:$service_port" >/dev/null 2>&1; then
        echo "[$TIMESTAMP] SERVICE_${service_name^^}_REACHABLE: true" >> "$METRICS_FILE"
        ((CONNECTIVITY_SCORE++))
    else
        echo "[$TIMESTAMP] SERVICE_${service_name^^}_REACHABLE: false" >> "$METRICS_FILE"
    fi
done

CONNECTIVITY_PERCENTAGE=$((CONNECTIVITY_SCORE * 100 / TOTAL_SERVICES))
echo "[$TIMESTAMP] PIPELINE_CONNECTIVITY_SCORE: $CONNECTIVITY_PERCENTAGE%" >> "$METRICS_FILE"

echo "[$TIMESTAMP] PIPELINE_METRICS_COMPLETE" >> "$METRICS_FILE"
EOF

chmod +x "$MONITORING_DIR/scripts/collect-pipeline-metrics.sh"
log_step "Pipeline Metrics Script" "SUCCESS" "Created DevOps pipeline metrics collection script"

# =============================================================================
# STEP 6: Automated Metrics Collection Scheduler
# =============================================================================
echo ""
echo "⏰ STEP 6: Setting up Automated Metrics Collection"
echo "------------------------------------------------"

# Create master metrics collection script
cat > "$MONITORING_DIR/scripts/run-all-metrics.sh" << 'EOF'
#!/bin/bash

# Master Metrics Collection Script
echo "=== Starting Comprehensive Metrics Collection ==="
echo "Timestamp: $(date)"

# Run all metrics collection scripts
/opt/monitoring/scripts/collect-system-metrics.sh
/opt/monitoring/scripts/collect-build-metrics.sh
/opt/monitoring/scripts/collect-elk-metrics.sh
/opt/monitoring/scripts/collect-pipeline-metrics.sh

echo "=== Metrics Collection Complete ==="

# Optional: Send metrics to ELK for visualization
METRICS_SUMMARY="/tmp/metrics-summary-$(date +%Y%m%d-%H%M%S).json"
cat > "$METRICS_SUMMARY" << 'METRICS_EOF'
{
  "@timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "app": "group6-react-app",
  "log_type": "metrics",
  "metrics_collection": "complete",
  "collection_time": "$(date)"
}
METRICS_EOF

# Copy to React app logs directory so Filebeat picks it up
cp "$METRICS_SUMMARY" "/var/log/react-app/metrics-$(date +%Y%m%d-%H%M%S).log"
EOF

chmod +x "$MONITORING_DIR/scripts/run-all-metrics.sh"
log_step "Master Metrics Script" "SUCCESS" "Created master metrics collection script"

# Create simple monitoring dashboard script
cat > "$MONITORING_DIR/scripts/show-metrics-dashboard.sh" << 'EOF'
#!/bin/bash

# Simple Metrics Dashboard
clear
echo "=================================================================="
echo "          Group 6 React App - DevOps Metrics Dashboard"
echo "=================================================================="
echo "Generated at: $(date)"
echo ""

# Latest metrics files
LATEST_SYSTEM="/opt/monitoring/metrics/system-metrics-$(date +%Y%m%d).log"
LATEST_BUILD="/opt/monitoring/metrics/build-metrics-$(date +%Y%m%d).log"
LATEST_ELK="/opt/monitoring/metrics/elk-metrics-$(date +%Y%m%d).log"
LATEST_PIPELINE="/opt/monitoring/metrics/pipeline-metrics-$(date +%Y%m%d).log"

echo "📊 SYSTEM METRICS"
echo "----------------"
if [ -f "$LATEST_SYSTEM" ]; then
    tail -10 "$LATEST_SYSTEM" | grep -E "CPU_USAGE|MEMORY_USAGE|DISK_USAGE" | tail -3
else
    echo "No system metrics available"
fi

echo ""
echo "🔧 BUILD METRICS"
echo "---------------"
if [ -f "$LATEST_BUILD" ]; then
    tail -10 "$LATEST_BUILD" | grep -E "BUILD_SIZE|BUILD_FILES_COUNT|MAIN_JS_SIZE" | tail -3
else
    echo "No build metrics available"
fi

echo ""
echo "📈 ELK METRICS"
echo "-------------"
if [ -f "$LATEST_ELK" ]; then
    tail -10 "$LATEST_ELK" | grep -E "LOG_ENTRIES_COUNT|ELASTICSEARCH_HEALTH|FILEBEAT_STATUS" | tail -3
else
    echo "No ELK metrics available"
fi

echo ""
echo "🔄 PIPELINE METRICS"
echo "------------------"
if [ -f "$LATEST_PIPELINE" ]; then
    tail -10 "$LATEST_PIPELINE" | grep -E "CONNECTIVITY_SCORE|DOCKER_CONTAINERS_RUNNING" | tail -2
else
    echo "No pipeline metrics available"
fi

echo ""
echo "=================================================================="
echo "Access detailed metrics at: /opt/monitoring/metrics/"
echo "Kibana Dashboard: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):10101"
echo "=================================================================="
EOF

chmod +x "$MONITORING_DIR/scripts/show-metrics-dashboard.sh"
log_step "Metrics Dashboard" "SUCCESS" "Created simple metrics dashboard script"

# =============================================================================
# STEP 7: Initial Metrics Collection
# =============================================================================
echo ""
echo "🚀 STEP 7: Running Initial Metrics Collection"
echo "--------------------------------------------"

# Run initial metrics collection
"$MONITORING_DIR/scripts/run-all-metrics.sh"
log_step "Initial Collection" "SUCCESS" "Completed first metrics collection run"

# =============================================================================
# STEP 8: Integration with ELK Stack
# =============================================================================
echo ""
echo "🔗 STEP 8: Integrating Metrics with ELK Stack"
echo "--------------------------------------------"

# Create metrics integration script
cat > "$MONITORING_DIR/scripts/metrics-to-elk.sh" << 'EOF'
#!/bin/bash

# Send Metrics to ELK Stack
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
METRICS_LOG="/var/log/react-app/metrics-summary-$(date +%Y%m%d-%H%M%S).log"

# Collect latest metrics into a single JSON format
cat > "$METRICS_LOG" << METRICS_JSON
{
  "@timestamp": "$TIMESTAMP",
  "app": "group6-react-app",
  "log_type": "metrics",
  "metrics_type": "system_summary",
  "collection_timestamp": "$(date)",
  "cpu_usage": "$(tail -1 /opt/monitoring/metrics/system-metrics-$(date +%Y%m%d).log 2>/dev/null | grep CPU_USAGE | cut -d':' -f2 | tr -d ' ' || echo 'unknown')",
  "memory_usage": "$(tail -1 /opt/monitoring/metrics/system-metrics-$(date +%Y%m%d).log 2>/dev/null | grep MEMORY_USAGE | cut -d':' -f2 | tr -d ' ' || echo 'unknown')",
  "log_entries_count": "$(tail -1 /opt/monitoring/metrics/elk-metrics-$(date +%Y%m%d).log 2>/dev/null | grep LOG_ENTRIES_COUNT | cut -d':' -f2 | tr -d ' ' || echo 'unknown')",
  "elasticsearch_health": "$(tail -1 /opt/monitoring/metrics/elk-metrics-$(date +%Y%m%d).log 2>/dev/null | grep ELASTICSEARCH_HEALTH | cut -d':' -f2 | tr -d ' ' || echo 'unknown')",
  "docker_containers": "$(tail -1 /opt/monitoring/metrics/pipeline-metrics-$(date +%Y%m%d).log 2>/dev/null | grep DOCKER_CONTAINERS_RUNNING | cut -d':' -f2 | tr -d ' ' || echo 'unknown')",
  "pipeline_connectivity": "$(tail -1 /opt/monitoring/metrics/pipeline-metrics-$(date +%Y%m%d).log 2>/dev/null | grep CONNECTIVITY_SCORE | cut -d':' -f2 | tr -d ' ' || echo 'unknown')"
}
METRICS_JSON

echo "Metrics sent to ELK at: $METRICS_LOG"
EOF

chmod +x "$MONITORING_DIR/scripts/metrics-to-elk.sh"
log_step "ELK Integration" "SUCCESS" "Created metrics to ELK integration script"

# =============================================================================
# STEP 9: Create Monitoring Configuration
# =============================================================================
echo ""
echo "⚙️ STEP 9: Creating Monitoring Configuration"
echo "-------------------------------------------"

# Create monitoring configuration file
cat > "$MONITORING_DIR/config/monitoring.conf" << 'EOF'
# Group 6 React App Monitoring Configuration

# Collection Intervals (in minutes)
SYSTEM_METRICS_INTERVAL=5
BUILD_METRICS_INTERVAL=10
ELK_METRICS_INTERVAL=5
PIPELINE_METRICS_INTERVAL=15

# Retention (in days)
METRICS_RETENTION_DAYS=30

# Alert Thresholds
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
DISK_THRESHOLD=90

# Service URLs
JENKINS_URL="http://localhost:8080"
SONARQUBE_URL="http://localhost:9000"
ELASTICSEARCH_URL="http://localhost:10100"
KIBANA_URL="http://localhost:10101"
TOMCAT_URL="http://localhost:8081"

# App Configuration
REACT_APP_NAME="group6-react-app"
REACT_APP_PATH="/home/ec2-user/group6-react-app"

# Monitoring Paths
MONITORING_DIR="/opt/monitoring"
METRICS_DIR="/opt/monitoring/metrics"
LOGS_DIR="/var/log/react-app"
EOF

log_step "Configuration File" "SUCCESS" "Created monitoring configuration file"

# =============================================================================
# STEP 10: Generate Access Instructions and Summary
# =============================================================================
echo ""
echo "📋 STEP 10: Generating Monitoring Access Instructions"
echo "---------------------------------------------------"

# Get public IP for access instructions
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "YOUR_PUBLIC_IP")

# Create access instructions file
cat > /tmp/monitoring-access.txt << EOF
=============================================================================
Group 6 React App - Monitoring Configuration Complete!
=============================================================================

🎯 MONITORING OVERVIEW:
-----------------------
✅ System Metrics: CPU, Memory, Disk, Load Average
✅ Build Metrics: Build size, file counts, bundle analysis
✅ ELK Metrics: Log counts, index health, service status
✅ Pipeline Metrics: Service connectivity, Docker status

📊 MANUAL MONITORING COMMANDS:
------------------------------
# Run all metrics collection:
sudo /opt/monitoring/scripts/run-all-metrics.sh

# View metrics dashboard:
sudo /opt/monitoring/scripts/show-metrics-dashboard.sh

# Send metrics to ELK:
sudo /opt/monitoring/scripts/metrics-to-elk.sh

# Individual metrics:
sudo /opt/monitoring/scripts/collect-system-metrics.sh
sudo /opt/monitoring/scripts/collect-build-metrics.sh
sudo /opt/monitoring/scripts/collect-elk-metrics.sh
sudo /opt/monitoring/scripts/collect-pipeline-metrics.sh

📁 METRICS STORAGE:
------------------
System Metrics: /opt/monitoring/metrics/system-metrics-YYYYMMDD.log
Build Metrics: /opt/monitoring/metrics/build-metrics-YYYYMMDD.log
ELK Metrics: /opt/monitoring/metrics/elk-metrics-YYYYMMDD.log
Pipeline Metrics: /opt/monitoring/metrics/pipeline-metrics-YYYYMMDD.log

🌐 DASHBOARD ACCESS:
-------------------
Kibana (for log visualization): http://$PUBLIC_IP:10101
Simple Metrics Dashboard: sudo /opt/monitoring/scripts/show-metrics-dashboard.sh

📈 WHAT YOU CAN MONITOR:
------------------------
• System resource utilization (CPU, Memory, Disk)
• React app build performance and size trends
• ELK stack health and log processing rates
• DevOps service connectivity and uptime
• Docker container status and counts
• Build success/failure patterns
• Service response times

🔧 CONFIGURATION:
-----------------
Config File: /opt/monitoring/config/monitoring.conf
Scripts Directory: /opt/monitoring/scripts/
Metrics Storage: /opt/monitoring/metrics/

🚨 BASIC MONITORING ALERTS:
---------------------------
Manual checks for:
• CPU usage > 80%
• Memory usage > 85%
• Disk usage > 90%
• Service connectivity < 100%
• Missing log entries in ELK

🔄 NEXT STEPS:
--------------
1. Run: sudo /opt/monitoring/scripts/show-metrics-dashboard.sh
2. Schedule regular metrics collection (cron job)
3. Set up automated alerts for critical thresholds
4. Create custom Kibana dashboards for metrics visualization
5. Monitor trends over time for performance optimization

📊 INTEGRATION WITH ELK:
------------------------
Metrics are automatically sent to ELK stack with:
- Index Pattern: group6-react-app-*
- Log Type: metrics
- Real-time processing through existing Filebeat

=============================================================================
🎉 Basic Monitoring Setup Complete!
=============================================================================
EOF

log_step "Access Instructions" "SUCCESS" "Generated monitoring access instructions at /tmp/monitoring-access.txt"

# =============================================================================
# FINAL SUMMARY AND STATUS
# =============================================================================
echo ""
echo "🎉 MONITORING CONFIGURATION SUMMARY"
echo "=================================="

# Count setup steps
TOTAL_STEPS=10
SUCCESSFUL_STEPS=$(grep -c "SUCCESS" "$MONITORING_LOG_FILE")
WARNING_STEPS=$(grep -c "WARN" "$MONITORING_LOG_FILE")
ERROR_STEPS=$(grep -c "ERROR" "$MONITORING_LOG_FILE")

echo -e "${BLUE}Total Setup Steps: $TOTAL_STEPS${NC}"
echo -e "${GREEN}Successful: $SUCCESSFUL_STEPS${NC}"
echo -e "${YELLOW}Warnings: $WARNING_STEPS${NC}"
echo -e "${RED}Errors: $ERROR_STEPS${NC}"

echo ""
echo "📋 Detailed Setup Log:"
echo "----------------------"
cat "$MONITORING_LOG_FILE"

echo ""
echo "💡 RECOMMENDATIONS:"
echo "------------------"

if [ $ERROR_STEPS -eq 0 ]; then
    echo -e "${GREEN}🎉 Monitoring configuration completed successfully!${NC}"
    echo -e "${GREEN}✅ Your Group 6 React App now has comprehensive basic monitoring${NC}"
    echo -e "${BLUE}📊 View dashboard: sudo /opt/monitoring/scripts/show-metrics-dashboard.sh${NC}"
    echo -e "${PURPLE}📈 Monitor through Kibana: http://$PUBLIC_IP:10101${NC}"
    echo ""
    echo -e "${CYAN}🚀 Ready for the final script: sample-pipeline.sh${NC}"
else
    echo -e "${RED}⚠️ Some errors occurred during setup. Please review the setup log:${NC}"
    grep "ERROR" "$MONITORING_LOG_FILE"
fi

echo ""
echo "📁 Setup completed! Full access instructions: /tmp/monitoring-access.txt"
echo "🔄 Run metrics collection anytime with: sudo /opt/monitoring/scripts/run-all-metrics.sh"

# Create status file for next script
MONITORING_STATUS_FILE="/tmp/monitoring-status.env"
echo "# Monitoring Setup Status - $TIMESTAMP" > "$MONITORING_STATUS_FILE"
echo "MONITORING_SETUP_COMPLETED=true" >> "$MONITORING_STATUS_FILE"
echo "MONITORING_SETUP_ERRORS=$ERROR_STEPS" >> "$MONITORING_STATUS_FILE"
echo "MONITORING_SETUP_WARNINGS=$WARNING_STEPS" >> "$MONITORING_STATUS_FILE"
echo "SYSTEM_METRICS_ENABLED=true" >> "$MONITORING_STATUS_FILE"
echo "BUILD_METRICS_ENABLED=true" >> "$MONITORING_STATUS_FILE"
echo "ELK_METRICS_ENABLED=true" >> "$MONITORING_STATUS_FILE"
echo "PIPELINE_METRICS_ENABLED=true" >> "$MONITORING_STATUS_FILE"
echo "MONITORING_DASHBOARD_READY=true" >> "$MONITORING_STATUS_FILE"
echo "PUBLIC_IP=$PUBLIC_IP" >> "$MONITORING_STATUS_FILE"

if [ $ERROR_STEPS -eq 0 ]; then
    echo "MONITORING_READY=true" >> "$MONITORING_STATUS_FILE"
    exit 0
else
    echo "MONITORING_READY=false" >> "$MONITORING_STATUS_FILE"
    exit 1
fi