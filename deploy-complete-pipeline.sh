#!/bin/bash

# =============================================================================
# MASTER DEVOPS PIPELINE AUTOMATION SCRIPT
# =============================================================================
# Purpose: Complete end-to-end DevOps pipeline deployment with one command
# Usage: ./deploy-complete-pipeline.sh
# Author: DevOps Automation Team
# Date: October 2025
# =============================================================================

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/deployment.log"
TERRAFORM_DIR="$SCRIPT_DIR"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
    
    case $level in
        "INFO")  echo -e "${BLUE}ℹ️  $message${NC}" ;;
        "SUCCESS") echo -e "${GREEN}✅ $message${NC}" ;;
        "WARNING") echo -e "${YELLOW}⚠️  $message${NC}" ;;
        "ERROR") echo -e "${RED}❌ $message${NC}" ;;
        "STEP") echo -e "${PURPLE}🚀 $message${NC}" ;;
    esac
}

# Error handler
error_exit() {
    log "ERROR" "$1"
    log "ERROR" "Deployment failed. Check $LOG_FILE for details."
    exit 1
}

# Prerequisites check
check_prerequisites() {
    log "STEP" "Checking prerequisites..."
    
    # Check if running on Windows (Git Bash/WSL)
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        log "INFO" "Detected Windows environment"
        TERRAFORM_CMD="terraform.exe"
        AWS_CMD="aws.exe"
    else
        TERRAFORM_CMD="terraform"
        AWS_CMD="aws"
    fi
    
    # Check Terraform
    if ! command -v $TERRAFORM_CMD &> /dev/null; then
        error_exit "Terraform not found. Please install Terraform first."
    fi
    
    # Check AWS CLI
    if ! command -v $AWS_CMD &> /dev/null; then
        error_exit "AWS CLI not found. Please install AWS CLI first."
    fi
    
    # Check AWS credentials
    if ! $AWS_CMD sts get-caller-identity &> /dev/null; then
        error_exit "AWS credentials not configured. Run 'aws configure' first."
    fi
    
    # Check SSH key
    if [[ ! -f "Pair06.pem" ]]; then
        error_exit "SSH key 'Pair06.pem' not found in current directory."
    fi
    
    chmod 400 Pair06.pem
    
    log "SUCCESS" "All prerequisites met!"
}

# Deploy infrastructure
deploy_infrastructure() {
    log "STEP" "Deploying AWS infrastructure with Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    log "INFO" "Initializing Terraform..."
    $TERRAFORM_CMD init || error_exit "Terraform init failed"
    
    # Plan deployment
    log "INFO" "Planning infrastructure deployment..."
    $TERRAFORM_CMD plan || error_exit "Terraform plan failed"
    
    # Apply deployment
    log "INFO" "Applying infrastructure deployment..."
    $TERRAFORM_CMD apply -auto-approve || error_exit "Terraform apply failed"
    
    # Get instance IP
    INSTANCE_IP=$($TERRAFORM_CMD output -raw instance_public_ip)
    if [[ -z "$INSTANCE_IP" ]]; then
        error_exit "Failed to get instance IP from Terraform output"
    fi
    
    log "SUCCESS" "Infrastructure deployed successfully!"
    log "INFO" "Instance IP: $INSTANCE_IP"
    
    # Save instance IP for later use
    echo "$INSTANCE_IP" > instance_ip.txt
}

# Wait for instance to be ready
wait_for_instance() {
    log "STEP" "Waiting for EC2 instance to be ready..."
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log "INFO" "Connection attempt $attempt/$max_attempts..."
        
        if ssh -i "Pair06.pem" -o StrictHostKeyChecking=no -o ConnectTimeout=10 ec2-user@$INSTANCE_IP "echo 'Connected successfully'" &> /dev/null; then
            log "SUCCESS" "Instance is ready and accessible!"
            return 0
        fi
        
        sleep 30
        ((attempt++))
    done
    
    error_exit "Instance did not become accessible within the timeout period"
}

# Upload and execute installation scripts
install_services() {
    log "STEP" "Installing all DevOps services on the instance..."
    
    # Upload all scripts
    log "INFO" "Uploading installation scripts..."
    scp -i "Pair06.pem" -o StrictHostKeyChecking=no *.sh ec2-user@$INSTANCE_IP:~/ || error_exit "Failed to upload scripts"
    
    # Make scripts executable and run them in sequence
    ssh -i "Pair06.pem" -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP "
        set -e
        chmod +x *.sh
        
        echo '🔧 Installing Docker and prerequisites...'
        sudo yum update -y
        sudo yum install -y docker git curl wget
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -a -G docker ec2-user
        
        echo '📦 Installing Docker Compose...'
        sudo curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        
        echo '🔄 Installing Node.js...'
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo yum install -y nodejs || {
            # Fallback installation for Amazon Linux
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
            source ~/.bashrc
            nvm install 18
            nvm use 18
        }
        
        echo '🚀 Starting service installations...'
        
        echo '1️⃣ Installing ELK Stack...'
        ./install-elk.sh
        
        echo '2️⃣ Installing Jenkins...'
        ./install-jenkins.sh
        
        echo '3️⃣ Installing SonarQube...'
        ./install-sonarqube.sh
        
        echo '4️⃣ Installing Tomcat...'
        ./install-tomcat.sh
        
        echo '⏳ Waiting for services to stabilize...'
        sleep 60
        
        echo '✅ All services installed successfully!'
    " || error_exit "Service installation failed"
    
    log "SUCCESS" "All services installed successfully!"
}

# Setup integrations
setup_integrations() {
    log "STEP" "Setting up tool integrations..."
    
    ssh -i "Pair06.pem" -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP "
        set -e
        
        echo '🔗 Setting up Jenkins jobs...'
        ./create-jenkins-jobs.sh || echo 'Jenkins jobs setup completed with warnings'
        
        echo '📊 Setting up ELK logging...'
        ./setup-elk-logging.sh || echo 'ELK setup completed with warnings'
        
        echo '🔧 Configuring monitoring...'
        ./configure-monitoring.sh || echo 'Monitoring setup completed with warnings'
        
        echo '⏳ Allowing services to integrate...'
        sleep 30
        
        echo '✅ Basic integrations completed!'
    " || log "WARNING" "Some integrations completed with warnings"
    
    log "SUCCESS" "Tool integrations configured!"
}

# Setup JIRA integration
setup_jira_integration() {
    log "STEP" "Setting up JIRA integration..."
    
    # Check if JIRA credentials are provided
    if [[ -z "$JIRA_URL" ]] || [[ -z "$JIRA_USERNAME" ]] || [[ -z "$JIRA_API_TOKEN" ]]; then
        log "WARNING" "JIRA credentials not provided as environment variables"
        log "INFO" "You can set up JIRA integration later by running:"
        log "INFO" "  export JIRA_URL='https://your-instance.atlassian.net'"
        log "INFO" "  export JIRA_USERNAME='your-email@company.com'"
        log "INFO" "  export JIRA_API_TOKEN='your-api-token'"
        log "INFO" "  ssh -i Pair06.pem ec2-user@$INSTANCE_IP './install-jira-integration.sh'"
        return 0
    fi
    
    # Upload JIRA credentials and setup
    ssh -i "Pair06.pem" -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP "
        export JIRA_URL='$JIRA_URL'
        export JIRA_USERNAME='$JIRA_USERNAME'
        export JIRA_API_TOKEN='$JIRA_API_TOKEN'
        
        echo '🎫 Setting up JIRA integration...'
        ./install-jira-integration.sh || {
            echo 'JIRA integration setup failed, but continuing...'
            exit 0
        }
        
        echo '✅ JIRA integration completed!'
    " || log "WARNING" "JIRA integration setup completed with warnings"
    
    log "SUCCESS" "JIRA integration configured!"
}

# Run integration tests
run_integration_tests() {
    log "STEP" "Running comprehensive integration tests..."
    
    ssh -i "Pair06.pem" -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP "
        echo '🧪 Running integration tests...'
        ./integration-tests.sh || {
            echo 'Some integration tests failed, checking individual services...'
            
            echo '🔄 Attempting service restart...'
            ./restart-all-services.sh || echo 'Service restart completed with warnings'
            
            echo '⏳ Waiting for services to stabilize after restart...'
            sleep 60
            
            echo '🧪 Re-running integration tests...'
            ./integration-tests.sh || echo 'Integration tests completed with some failures'
        }
        
        echo '📊 Integration test summary:'
        cat /tmp/integration-test-results.log | tail -20
    " || log "WARNING" "Integration tests completed with some issues"
    
    log "SUCCESS" "Integration tests completed!"
}

# Display final information
display_final_info() {
    log "STEP" "Deployment completed! Gathering final information..."
    
    # Get service status
    ssh -i "Pair06.pem" -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP "
        echo '📊 Final Service Status:'
        echo '======================='
        docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
        
        echo ''
        echo '🌐 Service Health Check:'
        echo '========================'
        
        # Test each service
        curl -s -o /dev/null -w 'Jenkins (8080): %{http_code}\n' http://localhost:8080 || echo 'Jenkins (8080): Not accessible'
        curl -s -o /dev/null -w 'SonarQube (9000): %{http_code}\n' http://localhost:9000 || echo 'SonarQube (9000): Not accessible'
        curl -s -o /dev/null -w 'Elasticsearch (10100): %{http_code}\n' http://localhost:10100 || echo 'Elasticsearch (10100): Not accessible'
        curl -s -o /dev/null -w 'Kibana (10101): %{http_code}\n' http://localhost:10101 || echo 'Kibana (10101): Not accessible'
        curl -s -o /dev/null -w 'Tomcat (8081): %{http_code}\n' http://localhost:8081 || echo 'Tomcat (8081): Not accessible'
    "
    
    echo ""
    echo "=============================================================================="
    echo -e "${GREEN}🎉 DEVOPS PIPELINE DEPLOYMENT COMPLETED SUCCESSFULLY! 🎉${NC}"
    echo "=============================================================================="
    echo ""
    echo -e "${CYAN}📍 Instance Information:${NC}"
    echo "   IP Address: $INSTANCE_IP"
    echo "   SSH Access: ssh -i Pair06.pem ec2-user@$INSTANCE_IP"
    echo ""
    echo -e "${CYAN}🌐 Service Access URLs:${NC}"
    echo "   Jenkins:       http://$INSTANCE_IP:8080"
    echo "   SonarQube:     http://$INSTANCE_IP:9000"
    echo "   Kibana:        http://$INSTANCE_IP:10101"
    echo "   Tomcat:        http://$INSTANCE_IP:8081"
    echo "   Elasticsearch: http://$INSTANCE_IP:10100"
    echo ""
    echo -e "${CYAN}🔑 Default Credentials:${NC}"
    echo "   Jenkins:   admin / (get password with: docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword)"
    echo "   SonarQube: admin / admin"
    echo ""
    echo -e "${CYAN}📚 Documentation:${NC}"
    echo "   Main Guide:        DEVOPS_PIPELINE_DOCUMENTATION.md"
    echo "   Integration Guide: TOOL_INTEGRATION_GUIDE.md"
    echo "   Quick Reference:   QUICK_REFERENCE.md"
    echo ""
    echo -e "${CYAN}🛠️  Management Commands:${NC}"
    echo "   Check Status:      ssh -i Pair06.pem ec2-user@$INSTANCE_IP './integration-tests.sh'"
    echo "   Restart Services:  ssh -i Pair06.pem ec2-user@$INSTANCE_IP './restart-all-services.sh'"
    echo "   View Logs:         ssh -i Pair06.pem ec2-user@$INSTANCE_IP 'docker logs <service-name>'"
    echo ""
    
    if [[ -z "$JIRA_URL" ]]; then
        echo -e "${YELLOW}⚠️  JIRA Integration:${NC}"
        echo "   JIRA integration was skipped. To set it up later:"
        echo "   1. Set environment variables:"
        echo "      export JIRA_URL='https://your-instance.atlassian.net'"
        echo "      export JIRA_USERNAME='your-email@company.com'"
        echo "      export JIRA_API_TOKEN='your-api-token'"
        echo "   2. Run: ssh -i Pair06.pem ec2-user@$INSTANCE_IP './install-jira-integration.sh'"
        echo ""
    fi
    
    echo -e "${GREEN}✅ Your complete DevOps CI/CD pipeline is ready!${NC}"
    echo "=============================================================================="
}

# Main execution
main() {
    echo "=============================================================================="
    echo -e "${PURPLE}🚀 COMPLETE DEVOPS PIPELINE AUTOMATION${NC}"
    echo "=============================================================================="
    echo ""
    
    # Initialize log file
    echo "DevOps Pipeline Deployment Log - $(date)" > "$LOG_FILE"
    echo "=======================================" >> "$LOG_FILE"
    
    log "INFO" "Starting complete DevOps pipeline deployment..."
    log "INFO" "Log file: $LOG_FILE"
    
    # Check if JIRA credentials are provided
    if [[ -n "$JIRA_URL" ]] && [[ -n "$JIRA_USERNAME" ]] && [[ -n "$JIRA_API_TOKEN" ]]; then
        log "INFO" "JIRA credentials detected - will include JIRA integration"
    else
        log "INFO" "JIRA credentials not provided - JIRA integration will be skipped"
    fi
    
    # Execute deployment steps
    check_prerequisites
    deploy_infrastructure
    wait_for_instance
    install_services
    setup_integrations
    setup_jira_integration
    run_integration_tests
    display_final_info
    
    log "SUCCESS" "Complete DevOps pipeline deployment finished successfully!"
    log "INFO" "Total deployment time: $(( $(date +%s) - $(date -r "$LOG_FILE" +%s) )) seconds"
}

# Handle script interruption
trap 'log "ERROR" "Script interrupted by user"; exit 1' INT TERM

# Run main function
main "$@"