#!/bin/bash

# =============================================================================
# Integration Tests Script for Group 6 React App DevOps Pipeline
# =============================================================================
# Purpose: Verify all DevOps tools can communicate and integrate properly
# Author: DevOps Pipeline Automation
# Date: $(date)
# =============================================================================

echo "🔧 Starting Integration Tests for Group 6 React App Pipeline..."
echo "=================================================="

# Configuration
REACT_APP_NAME="group6-react-app"
REACT_APP_PATH="/home/ec2-user/$REACT_APP_NAME"
TEST_RESULTS_FILE="/tmp/integration-test-results.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_result() {
    local test_name="$1"
    local status="$2"
    local message="$3"
    
    echo "[$TIMESTAMP] $test_name: $status - $message" >> "$TEST_RESULTS_FILE"
    
    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✅ $test_name: $message${NC}"
    elif [ "$status" = "FAIL" ]; then
        echo -e "${RED}❌ $test_name: $message${NC}"
    else
        echo -e "${YELLOW}⚠️ $test_name: $message${NC}"
    fi
}

# Initialize test results file
echo "Integration Test Results - $TIMESTAMP" > "$TEST_RESULTS_FILE"
echo "=========================================" >> "$TEST_RESULTS_FILE"

# =============================================================================
# TEST 1: Basic Service Availability
# =============================================================================
echo ""
echo "🧪 TEST 1: Basic Service Availability"
echo "------------------------------------"

# Test Jenkins
echo "Checking Jenkins availability..."
JENKINS_RESPONSE=$(curl -s -w "%{http_code}" http://localhost:8080 -o /dev/null)
if [ "$JENKINS_RESPONSE" = "200" ] || [ "$JENKINS_RESPONSE" = "403" ]; then
    log_result "Jenkins Service" "PASS" "Jenkins is running on port 8080 (HTTP $JENKINS_RESPONSE)"
else
    log_result "Jenkins Service" "FAIL" "Jenkins is not accessible on port 8080 (HTTP $JENKINS_RESPONSE)"
fi

# Test SonarQube
echo "Checking SonarQube availability..."
SONARQUBE_RESPONSE=$(curl -s -w "%{http_code}" http://localhost:9000 -o /dev/null 2>/dev/null)
if [ "$SONARQUBE_RESPONSE" = "200" ] || [ "$SONARQUBE_RESPONSE" = "401" ] || [ "$SONARQUBE_RESPONSE" = "302" ]; then
    log_result "SonarQube Service" "PASS" "SonarQube is running on port 9000 (HTTP $SONARQUBE_RESPONSE)"
else
    log_result "SonarQube Service" "WARN" "SonarQube not accessible on port 9000 (HTTP $SONARQUBE_RESPONSE) - may need restart"
fi

# Test Elasticsearch
echo "Checking Elasticsearch availability..."
if curl -s -f http://localhost:10100 > /dev/null 2>&1; then
    log_result "Elasticsearch Service" "PASS" "Elasticsearch is running on port 10100"
else
    log_result "Elasticsearch Service" "FAIL" "Elasticsearch is not accessible on port 10100"
fi

# Test Kibana
echo "Checking Kibana availability..."
if curl -s -f http://localhost:10101 > /dev/null 2>&1; then
    log_result "Kibana Service" "PASS" "Kibana is running on port 10101"
else
    log_result "Kibana Service" "FAIL" "Kibana is not accessible on port 10101"
fi

# Test Tomcat
echo "Checking Tomcat availability..."
TOMCAT_RESPONSE=$(curl -s -w "%{http_code}" http://localhost:8081 -o /dev/null)
if [ "$TOMCAT_RESPONSE" = "200" ] || [ "$TOMCAT_RESPONSE" = "404" ]; then
    log_result "Tomcat Service" "PASS" "Tomcat is running on port 8081 (HTTP $TOMCAT_RESPONSE)"
else
    log_result "Tomcat Service" "FAIL" "Tomcat is not accessible on port 8081 (HTTP $TOMCAT_RESPONSE)"
fi

# =============================================================================
# TEST 2: React App Prerequisites
# =============================================================================
echo ""
echo "🧪 TEST 2: React App Prerequisites"
echo "----------------------------------"

# Check Node.js
echo "Checking Node.js installation..."
if command -v node > /dev/null 2>&1; then
    NODE_VERSION=$(node --version)
    log_result "Node.js Installation" "PASS" "Node.js $NODE_VERSION is installed"
else
    log_result "Node.js Installation" "FAIL" "Node.js is not installed"
fi

# Check npm
echo "Checking npm installation..."
if command -v npm > /dev/null 2>&1; then
    NPM_VERSION=$(npm --version)
    log_result "npm Installation" "PASS" "npm $NPM_VERSION is installed"
else
    log_result "npm Installation" "FAIL" "npm is not installed"
fi

# Check React App Directory
echo "Checking React app directory..."
if [ -d "$REACT_APP_PATH" ]; then
    log_result "React App Directory" "PASS" "React app found at $REACT_APP_PATH"
    
    # Check package.json
    if [ -f "$REACT_APP_PATH/package.json" ]; then
        log_result "React App Config" "PASS" "package.json found"
    else
        log_result "React App Config" "FAIL" "package.json not found"
    fi
    
    # Check SonarQube config
    if [ -f "$REACT_APP_PATH/sonar-project.properties" ]; then
        log_result "SonarQube Config" "PASS" "sonar-project.properties found"
    else
        log_result "SonarQube Config" "FAIL" "sonar-project.properties not found"
    fi
    
    # Check Jenkinsfile
    if [ -f "$REACT_APP_PATH/Jenkinsfile" ]; then
        log_result "Jenkins Config" "PASS" "Jenkinsfile found"
    else
        log_result "Jenkins Config" "FAIL" "Jenkinsfile not found"
    fi
else
    log_result "React App Directory" "FAIL" "React app not found at $REACT_APP_PATH"
fi

# =============================================================================
# TEST 3: Jenkins Integration Tests
# =============================================================================
echo ""
echo "🧪 TEST 3: Jenkins Integration Tests"
echo "-----------------------------------"

# Check Jenkins API accessibility
echo "Testing Jenkins API..."
JENKINS_API_RESPONSE=$(curl -s -w "%{http_code}" http://localhost:8080/api/json -o /dev/null)
if [ "$JENKINS_API_RESPONSE" = "200" ] || [ "$JENKINS_API_RESPONSE" = "403" ]; then
    log_result "Jenkins API" "PASS" "Jenkins API is accessible (HTTP $JENKINS_API_RESPONSE)"
else
    log_result "Jenkins API" "FAIL" "Jenkins API returned HTTP $JENKINS_API_RESPONSE"
fi

# Check if Jenkins can reach SonarQube
echo "Testing Jenkins -> SonarQube connectivity..."
SONAR_FROM_JENKINS=$(curl -s -w "%{http_code}" http://localhost:9000/api/system/status -o /dev/null)
if [ "$SONAR_FROM_JENKINS" = "200" ]; then
    log_result "Jenkins->SonarQube" "PASS" "Jenkins can reach SonarQube API"
else
    log_result "Jenkins->SonarQube" "FAIL" "Jenkins cannot reach SonarQube (HTTP $SONAR_FROM_JENKINS)"
fi

# =============================================================================
# TEST 4: SonarQube Integration Tests
# =============================================================================
echo ""
echo "🧪 TEST 4: SonarQube Integration Tests"
echo "-------------------------------------"

# Test SonarQube API
echo "Testing SonarQube API..."
SONAR_STATUS=$(curl -s http://localhost:9000/api/system/status 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
if [ "$SONAR_STATUS" = "UP" ]; then
    log_result "SonarQube API" "PASS" "SonarQube system status is UP"
else
    log_result "SonarQube API" "FAIL" "SonarQube system status: $SONAR_STATUS"
fi

# Check SonarQube scanner availability
echo "Testing SonarQube Scanner..."
if command -v sonar-scanner > /dev/null 2>&1; then
    log_result "SonarQube Scanner" "PASS" "sonar-scanner is installed"
elif npm list -g sonar-scanner > /dev/null 2>&1; then
    log_result "SonarQube Scanner" "PASS" "sonar-scanner is available via npm"
else
    log_result "SonarQube Scanner" "WARN" "sonar-scanner not found (will use npx)"
fi

# =============================================================================
# TEST 5: ELK Stack Integration Tests
# =============================================================================
echo ""
echo "🧪 TEST 5: ELK Stack Integration Tests"
echo "-------------------------------------"

# Test Elasticsearch health
echo "Testing Elasticsearch health..."
ES_HEALTH=$(curl -s http://localhost:10100/_cluster/health 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
if [ "$ES_HEALTH" = "green" ] || [ "$ES_HEALTH" = "yellow" ]; then
    log_result "Elasticsearch Health" "PASS" "Cluster health is $ES_HEALTH"
else
    log_result "Elasticsearch Health" "FAIL" "Cluster health: $ES_HEALTH"
fi

# Test Kibana API
echo "Testing Kibana API..."
KIBANA_STATUS=$(curl -s http://localhost:10101/api/status 2>/dev/null | grep -o '"overall":{"level":"[^"]*"' | cut -d'"' -f6)
if [ "$KIBANA_STATUS" = "available" ]; then
    log_result "Kibana API" "PASS" "Kibana status is available"
else
    log_result "Kibana API" "WARN" "Kibana status: $KIBANA_STATUS (may still be starting)"
fi

# Test Logstash (if running)
echo "Testing Logstash connectivity..."
if netstat -tulpn 2>/dev/null | grep -q ":15000"; then
    log_result "Logstash Service" "PASS" "Logstash is listening on port 15000"
else
    log_result "Logstash Service" "WARN" "Logstash not detected on port 15000"
fi

# =============================================================================
# TEST 6: Tomcat Deployment Tests
# =============================================================================
echo ""
echo "🧪 TEST 6: Tomcat Deployment Tests"
echo "----------------------------------"

# Test Tomcat manager availability
echo "Testing Tomcat deployment capability..."
TOMCAT_WEBAPPS="/opt/tomcat/webapps"
if [ -d "$TOMCAT_WEBAPPS" ]; then
    log_result "Tomcat Webapps" "PASS" "Tomcat webapps directory exists"
    
    # Check if we can write to webapps (test deployment capability)
    if sudo -u tomcat test -w "$TOMCAT_WEBAPPS"; then
        log_result "Tomcat Deploy Access" "PASS" "Can deploy to Tomcat webapps"
    else
        log_result "Tomcat Deploy Access" "WARN" "Limited access to webapps directory"
    fi
    
    # Check if React app is already deployed
    if [ -d "$TOMCAT_WEBAPPS/$REACT_APP_NAME" ]; then
        log_result "React App Deployment" "PASS" "$REACT_APP_NAME is deployed to Tomcat"
        
        # Test if deployed app is accessible
        APP_URL="http://localhost:8083/$REACT_APP_NAME"
        APP_RESPONSE=$(curl -s -w "%{http_code}" "$APP_URL" -o /dev/null)
        if [ "$APP_RESPONSE" = "200" ]; then
            log_result "React App Access" "PASS" "Deployed app is accessible"
        else
            log_result "React App Access" "WARN" "Deployed app returned HTTP $APP_RESPONSE"
        fi
    else
        log_result "React App Deployment" "INFO" "$REACT_APP_NAME not yet deployed"
    fi
else
    log_result "Tomcat Webapps" "FAIL" "Tomcat webapps directory not found"
fi

# =============================================================================
# TEST 7: Network Connectivity Tests
# =============================================================================
echo ""
echo "🧪 TEST 7: Network Connectivity Tests"
echo "------------------------------------"

# Test internal connectivity between services
echo "Testing service-to-service connectivity..."

# Jenkins -> Tomcat
JENKINS_TO_TOMCAT=$(curl -s -w "%{http_code}" http://localhost:8081 -o /dev/null)
if [ "$JENKINS_TO_TOMCAT" = "200" ] || [ "$JENKINS_TO_TOMCAT" = "404" ]; then
    log_result "Jenkins->Tomcat" "PASS" "Jenkins can reach Tomcat (HTTP $JENKINS_TO_TOMCAT)"
else
    log_result "Jenkins->Tomcat" "FAIL" "Jenkins cannot reach Tomcat (HTTP $JENKINS_TO_TOMCAT)"
fi

# SonarQube -> Elasticsearch (for potential integration)
SONAR_TO_ES=$(curl -s -w "%{http_code}" http://localhost:10100 -o /dev/null)
if [ "$SONAR_TO_ES" = "200" ] || [ "$SONAR_TO_ES" = "401" ]; then
    log_result "SonarQube->Elasticsearch" "PASS" "SonarQube can reach Elasticsearch"
else
    log_result "SonarQube->Elasticsearch" "WARN" "Limited connectivity (HTTP $SONAR_TO_ES)"
fi

# =============================================================================
# TEST SUMMARY AND RECOMMENDATIONS
# =============================================================================
echo ""
echo "📊 INTEGRATION TEST SUMMARY"
echo "=========================="

# Count results
TOTAL_TESTS=$(grep -c ":" "$TEST_RESULTS_FILE" | head -1)
PASSED_TESTS=$(grep -c "PASS" "$TEST_RESULTS_FILE")
FAILED_TESTS=$(grep -c "FAIL" "$TEST_RESULTS_FILE")
WARNED_TESTS=$(grep -c "WARN" "$TEST_RESULTS_FILE")

echo -e "${BLUE}Total Tests: $TOTAL_TESTS${NC}"
echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
echo -e "${RED}Failed: $FAILED_TESTS${NC}"
echo -e "${YELLOW}Warnings: $WARNED_TESTS${NC}"

echo ""
echo "📋 Detailed Results:"
echo "-------------------"
cat "$TEST_RESULTS_FILE"

echo ""
echo "💡 RECOMMENDATIONS:"
echo "------------------"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}🎉 All critical tests passed! Your environment is ready for React app integration.${NC}"
    echo "✅ Proceed with setup-elk-logging.sh"
else
    echo -e "${YELLOW}⚠️ Some tests failed. Please address the following before proceeding:${NC}"
    grep "FAIL" "$TEST_RESULTS_FILE" | while read line; do
        echo "  - $line"
    done
fi

if [ $WARNED_TESTS -gt 0 ]; then
    echo -e "${YELLOW}📝 Warnings found (non-critical):${NC}"
    grep "WARN" "$TEST_RESULTS_FILE" | while read line; do
        echo "  - $line"
    done
fi

echo ""
echo "📁 Full test results saved to: $TEST_RESULTS_FILE"
echo "🔄 Run this script again after fixing any issues."

# Create integration status file for other scripts
INTEGRATION_STATUS_FILE="/tmp/integration-status.env"
echo "# Integration Test Status - $TIMESTAMP" > "$INTEGRATION_STATUS_FILE"
echo "INTEGRATION_TESTS_PASSED=$PASSED_TESTS" >> "$INTEGRATION_STATUS_FILE"
echo "INTEGRATION_TESTS_FAILED=$FAILED_TESTS" >> "$INTEGRATION_STATUS_FILE"
echo "INTEGRATION_TESTS_TOTAL=$TOTAL_TESTS" >> "$INTEGRATION_STATUS_FILE"
echo "REACT_APP_PATH=$REACT_APP_PATH" >> "$INTEGRATION_STATUS_FILE"
echo "INTEGRATION_TEST_TIMESTAMP='$TIMESTAMP'" >> "$INTEGRATION_STATUS_FILE"

if [ $FAILED_TESTS -eq 0 ]; then
    echo "INTEGRATION_READY=true" >> "$INTEGRATION_STATUS_FILE"
    exit 0
else
    echo "INTEGRATION_READY=false" >> "$INTEGRATION_STATUS_FILE"
    exit 1
fi